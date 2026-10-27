# Verification

Types, finite tests, models, proofs and operational evidence establish different things.
None automatically certifies handwritten OCaml, external premise truth or household use.
Ordinary qualification is macOS x86_64 and Ubuntu 24.04 x86_64 (CI) with the locked
toolchain. This file keeps entries from 2026-10-20 on; earlier ones (including the bounded
Solo5-SPT engine boot) are in Git at `90a5867:docs/VERIFICATION.md`.

## Old names removed from the household book and Shell (2026-10-27)

- `Records` and `Book_log` folded into `Daily_book` (`change`, `apply`); `sexp/`
  (`bakhlo_sexp`) renamed `household/` (`bakhlo_household`); unused `Relation` and
  `Validity_revision` identifiers removed; synthetic test books named `*.txt`;
  `Daily_actions.publish_onto` names the base-revision guard; the empty
  `legacy_shared_literals` exemption removed from the architecture check.
- `Daily_draft`/`Daily_actions`/`Shell_state` no longer export the raising `get`/`get_id`:
  Daily Pace builds coordinates with `Daily_draft.coordinate` (a result), the Shell
  checks its start-up date explicitly, and the scenario fixture keeps the test helper.
- `Daily_overlays` split (668 → 151 lines): accounting roles have one owner,
  `Locus_roles` (file token and display label); the Balances rows moved verbatim to
  `screens/balances/balance_items` behind an `.mli`; the bonsai to the Home screen;
  the unused `progress_bar` removed. Synthetic Balances/Home checks pass unchanged;
  latest-data paired comparison of Balances and Home **not executed** for this move.
- No behaviour change intended: no format, UI text, admission rule or ordering of
  refusals changed (the reversal and batch commits keep their explicit order).
- Passed: `./tools/check`, `./tools/tui --self-check`, `./tools/format --check`,
  `git diff --check`, `./tools/privacy-scan --all`, `./tools/startup-probe 1000`
  (builds and runs; synthetic only). Not executed: latest-data paired comparison
  (no screen or displayed answer changed), physical terminal/IME, P7/power loss.
- Matching commit `08383f6` passed
  [CI run 40489301603](https://github.com/shumoku88-bit/bakhlo/actions/runs/40489301603)
  (Linux build, all tests, PTY matrix).

## Book publications retain one kind of recovery evidence (2026-10-27)

- Ordinary recording, Observe and roles/Attention share the store-outcome mapping.
  All retain the expected revision when a book publication is uncertain. Reload
  confirms a landed save without retry; an unconfirmed save remains stopped.
  Screen owners still own their modal responses and admission rules.
- `Daily_file.t` is a private record with an abstract file stamp. A negative
  compilation test rejects replacing book/path/revision; read-only clients compile.
  Scenario fixtures now load actual synthetic files and use real external writes
  or removed destinations for conflict/failure checks. An impossible malformed
  session was replaced by an explicit screen error environment; refusal assertions remain.
- Configuration and settlements share `write_atomic` under their existing locks.
  A new storage test covers creation, replacement, no `.prev` and temporary cleanup
  after failed rename. Their post-rename failures still return an error requiring
  inspection; this does not give auxiliary files book-publication recovery evidence.
- New cross-screen tests inject real writer faults before replacement and after
  durable replacement for Observe, roles and Attention. They assert retained
  expected revision, no retry on reload, confirmed/unconfirmed behavior, stale
  observation refusal and exact retention of unrelated Record drafts.
- Passed: clean unrestricted `./tools/check`, `./tools/tui --self-check`,
  `./tools/format --check`, `git diff --check`, and `./tools/privacy-scan --all`.
  Independent source review found no remaining blocker. P7/power loss remain unqualified.
- Matching implementation commit `21cfb920422e13e6a6053bf10f7cb37a09234041`
  passed [CI run 40486524266](https://github.com/shumoku88-bit/bakhlo/actions/runs/40486524266):
  Linux build, all contract/regression/TUI tests, and the PTY keyboard/resize/non-writing
  matrix. The subsequent completion note changes documentation only.

## Recording changes on latest read-only copies (2026-10-27)

- One fresh generation from `tools/compare refresh` was used for old Bakhlo,
  existing LOAM and new Bakhlo throughout. Actual PTY dimensions: 120×36 and 80×24.
  Flows: Record quick capture → Edit → valid Preview → cancel; Scheduled overview
  → Months → List → new → cancel; Balances and Daily Pace display.
- Old Bakhlo was `.run/bakhlo_tui.exe`, whose build stamp was `086c3aa`.
  SHA256: `2b36c095372ad70bde003c6cf8fd50cc188636f66aaa6ab126e95060a1fea167`.
  New native binary SHA256:
  `5c84646bc234afe2680b6f67d07a2e040087b8e04e9a705fb49de70c77f40777`.
  Existing LOAM binary SHA256:
  `d7a1ef1b4274cb255f6b9da3ec0c23716862127d3d71a1d7344ef08f1b8b6c04`.
  Its source checkout was `7190af22`; correspondence to that binary is not established.
- Bakhlo before/after: 24 captured frames were byte-identical. The two Record
  Preview frames were identical after substituting only their generated candidate
  ID (one substitution in each). Scheduled creation cancelled back to List in all
  three programs. LOAM was exercised on the same generation; this is not a claim
  of complete visual parity or semantic comparison of every displayed value.
  Its Balances `v` did not follow Bakhlo's Accounting route, so that extra view was not paired.
- Book/config SHA256s of the original and both copies were unchanged after each
  session batch. Private captures and inputs remain in ignored scratch only.
  The AI's own PTY processes were closed; `tools/compare clean-copies` kept only
  the selected generation. No household or comparison-book save was performed.
- Not executed: household save trials, full LOAM edge-case parity, physical IME,
  human acceptance, P7 and power loss.

## Record choices are explicit states (2026-10-27)

- Review uses named Publish/Edit/Cancel variants with exhaustive navigation and
  Enter dispatch. Original-amount editing names the Measure/amount field instead
  of encoding it as an integer. The public editor API is unchanged.
- Added public-input checks cover forward/backward wrap without changing the
  payload or reviewed revision, and Edit/Cancel while writes are stopped without
  losing the draft. Existing Record, original-amount and cross-screen tests pass.
- Integrated `./tools/check`, `./tools/tui --self-check` and formatting passed.
  This slice does not redesign every modal phase or change the review-size,
  review-to-end, stale-generation or publication guards.

## Scheduled remainder preserves exact drafts (2026-10-27)

- Preview and Ctrl-U now share signed-integer parsing, using `Z.t`. A balanced
  three-row draft keeps every row; replacing suspense excludes its old amount.
  Invalid input, ambiguous suspense destinations and a zero replacement keep the
  draft intact with an explicit notice.
- Public `Scheduled_session.handle` tests inspect the exact candidate and its
  conservation: existing suspense, repeated Ctrl-U, comma grouping, amounts beyond
  machine integers, malformed amounts and unchanged fields on refusal.
- The new tests fail against `086c3aa`'s implementation (balanced three-row case)
  and pass against the fix. Targeted native tests and the integrated full check,
  TUI self-check and formatting check passed. Preview/save guards remain in place.
- Synthetic checks establish the repaired helper; no LOAM edge-case parity or
  physical-terminal/IME acceptance is inferred from them.

## Amount text has one pure owner (2026-10-27)

- From `086c3aa`: `sexp/amount.ml` owns exact decimal/expression input and display;
  the public `Daily_book` API still supplies the Measure scale. Positive and signed
  input retain their different syntax and refusal precedence; decimal conversion is shared.
- New input-boundary and display/parse tests cover scales 0 through 9 and quantities
  beyond machine integers. The new tests plus existing `daily_book_tests.ml` ran 28
  tests successfully; the complete Core/oracle/storage tests also passed.
- The integrated working tree passed `./tools/check`, `./tools/tui --self-check` and
  `./tools/format --check`. The first sandboxed run picked up macOS Xcode diagnostics;
  after clearing generated build output, the unrestricted full run passed. No test
  expectations were changed to accommodate those diagnostics.
- No dependency, book format or public input API changed. Latest-copy UI comparison
  is recorded separately for the integrated recording changes.

## Code quality review (2026-10-27)

- Read-only source review at `086c3aa`, matching remote HEAD; initial tree clean.
  Inspected Core, book.txt admission, store, TUI owners/kit/protocol/Shell and their tests.
  No product code changes. Review conclusions are in `tasks/todo.md`.
- Passed: `./tools/check` (Core, TUI, architecture, privacy),
  `./tools/tui --self-check`, `./tools/format --check`.
- A temporary OCaml program linked existing build artifacts and called the public
  `Scheduled_session.handle` API with synthetic inputs at 80×24 (ASCII width function).
  Ctrl-U removed the balancing suspense row from `+1000 / -500 / unresolved:-500`;
  recalculating `+1000 / -400 / unresolved:-500` also left unequal totals.
  Preview refused both with `Scheduled posting totals differ.`
  With `+1,000` and an empty second row, Ctrl-U incorrectly said postings were already
  balanced. Preview refused the incomplete draft. These cases pass through the ordinary
  amount-input handler; no private state access or household files were used.
  The existing synthetic suites pass despite these gaps. No erroneous publication was shown.
- Not executed: latest-data paired comparison, physical-terminal/IME acceptance, P7,
  power loss. This was a code-quality review, not a behavioral parity or acceptance pass.

## Optional formatting brought clean, layout only (2026-10-27)

- Scope: the optional ocamlformat target on the main checkout, whose tree was clean at the
  `2b14c2b` 5.4.1 cutover. Layout only: no source semantics, serialization, fixture,
  generator or public API behavior was changed, and the root `.ocamlformat` stayed as
  pinned (0.29.0, default profile, target 5.4.1, margin 100, `wrap-comments = false`,
  `parse-docstrings = false`, so evidence prose is not reflowed).
- Config visibility: `tui/` carries its own `dune-project`, which kept the root
  `.ocamlformat` from reaching it, so the TUI tree had been left unformatted behind
  missing-configuration warnings. The added `tui/.ocamlformat` is a symlink to the root
  file: one canonical pinned config on both sides of the nested project boundary, no
  duplicated pins, no warning suppressed and no target skipped.
- Apply: `./tools/format --apply` exited 0 with a clean environment, temporary `HOME`/`XDG`
  directories and a minimal `PATH`/`LANG`/`TERM`; the wrapper's own post-apply `@fmt`
  check passed. It corrected 70 tracked source/Dune files of layout only, 57 of them under
  `tui/`.
- Check: `./tools/format --check` afterwards exited 0 with 0 bytes on stdout and 0 bytes on
  stderr, no warning and no `Error` line. ocamlformat's own AST/comment-preservation checks
  ran in these runs; nothing about the check itself was relaxed.
- Build and tests: `./tools/opam exec -- dune build --root . @all` and
  `./tools/opam exec -- dune runtest --root . --force` passed with the temporary
  `HOME`/`XDG` directories and without any inherited `OCAML*` workaround, so the layout
  edits left the synthetic Core/TUI suites as they were.
- Native runtime: the real `_build/default/tui/app/bakhlo_tui.exe --check examples/book.txt`
  exited 0 and admitted the synthetic daily book with no payload output;
  `tools/ci-tui-pty` on the same binary exited 0 at 120×36, 80×24, 48×14 and 32×9 with
  resize, keyboard, the exact `1,000` balance display, cold reopen and exit,
  unchanged fixture bytes, and unchanged authority after the Record draft, Preview and 32×9
  Publish-refusal steps plus Escape and cold draft resume. macOS x86_64 synthetic evidence
  only: no LOAM, IME or household claim.
- Excluded: `tools/check` and `tools/privacy-scan` as wrappers, the operational wrappers
  and `.run` state, Linux CI (not run) and the formatter vendor's own test suite. No
  permanent test was added, since this change is layout-only and the existing suite plus
  the native checks above are what was exercised. Nothing was committed or pushed for this
  entry.

## OCaml 5.4.1 locked baseline replay (stage, 2026-10-27)

- Scope: a separate ignored stage copy of this tree, not the main checkout, whose 5.3.0
  root/switch and `_build/` were left as they were. No household file, private comparison
  copy or LOAM data was read or written; only the tracked synthetic fixture
  `examples/book.txt` was used. This entry records the stage copy only; the main
  checkout's cutover at its permanent prefix is the next entry.
- Toolchain: checked local opam 2.6.0, frozen registry
  `ac27950e5eac6c981ad809dff370c937820b7893`, a new repository-local root and an OCaml
  5.4.1 switch, Dune 3.24.2, Base v0.17.3, Zarith 1.14, ppx_expect v0.17.3 and
  Base_quickcheck v0.17.1 with the locked `--with-test` set. The regenerated lock moved
  only the three compiler entries (`ocaml`, `ocaml-base-compiler`, `ocaml-compiler`) to
  5.4.1; every other pin is unchanged.
- `./tools/bootstrap` (locked, with test dependencies): pass. An existing switch holding
  another compiler is still refused, so the fail-closed guard survived the replay, and
  nothing is installed on the OS.
- `./tools/opam exec -- dune build --root . @all`: pass.
  `./tools/opam exec -- dune runtest --root . --force`: pass, run with `env -i` and
  temporary `HOME`/`XDG` directories, without an `OCAMLPARAM` workaround.
- `tools/ci-tui-pty _build/default/tui/app/bakhlo_tui.exe examples/book.txt` (real PTY,
  synthetic fixture): pass at 120×36, 80×24, 48×14 and 32×9, including resize, cold
  reopen, exactly 1,000 entries, Ctrl-Q and the Record Preview refusal at 32×9. The
  fixture bytes were unchanged and no extra authority writes appeared. macOS x86_64 PTY
  evidence only: no LOAM, IME, physical-terminal or household claim.
- Optional formatter, recreated with the documented recipe (`ocaml-system.5.4.1`,
  `dune.3.24.2`, `ocamlformat.0.29.0`, same frozen registry): a 5.4.1 formatting target
  and the wrapper's version/pin checks passed. `./tools/format --check` FAILS: 15
  pre-existing source/Dune layout diffs plus nested `tui/` config warnings, no `Error`
  lines. The main 5.3.0 baseline fails the same command on the same 15 files with
  identical correction hunks, so this is neither a 5.4.1 formatter regression nor a green
  gate; nothing was mass-formatted. Historical state: the layouts were corrected afterwards
  on the main checkout (see the formatting entry above).
- Linux CI (`.github/workflows/core.yml`) now pins 5.4.1 with the locked install; it was
  not run and nothing was committed or pushed.
- Excluded: `tools/check` as a wrapper. Its build and forced-test steps were run directly
  (above); its last step `tools/privacy-scan` was not run, since it needs the ignored
  household copies under `scratch/`, which this replay did not create or read. Also
  excluded: the formatter vendor's own test suite, ordinary source-package `opam install`
  qualification, and any household or LOAM acceptance.
- Follow-up: that cutover was completed on the main checkout on 2026-10-27 through this
  qualified bootstrap (see below). No stage copy is reused as evidence for the main
  checkout.

## OCaml 5.4.1 main checkout cutover (2026-10-27)

- Permanent prefix: the main checkout's 5.3.0 unit was moved whole into a private ignored
  backup, `.tools/ocaml-5.3.0-backup.<id>/`, holding `_opam/`, `.opam-root/` and `_build/`
  plus the formatter artifacts `format`, `format-root` and `format-compiler` from
  `.tools/`, with a `switch.export` inventory and the initial source archive. The checked
  `.tools/opam` binary stayed in place; a fresh repository-local root and switch were
  bootstrapped at the original paths. No stage or temporary prefix remains in the root,
  switch, findlib or formatter-root configuration. The compiler was built at the correct
  prefix on the stage and again here; no compiled switch was relocated for use.
- Backup preservation and restore: selected formatter directories were preserved with the
  old switch, not the whole `.tools/`. The backup is restorable but not runnable: restoring
  it means moving the unit whole back to its original paths *and* restoring the matching
  tracked 5.3.0 pin/lock/bootstrap/CI/formatter configuration from the pre-migration
  commit, because `tools/bootstrap` now pins 5.4.1 and still refuses a switch holding
  another compiler, and `tools/format` refuses a wrong local formatter. This is ignored
  development state only and contains no household file.
- Bootstrap: `./tools/bootstrap` passed at the permanent prefix with the checked opam
  2.6.0, the frozen registry `ac27950e5eac6c981ad809dff370c937820b7893` and the regenerated
  lock. The lock has 56 entries including the compiler: only `ocaml`,
  `ocaml-base-compiler` and `ocaml-compiler` moved to 5.4.1, and the other 53 pins are
  unchanged. Local ocaml-lsp 1.26.0 and utop 2.17 were installed compiler-matched as
  editor/REPL tools outside the tracked lock; the locked bootstrap re-ran clean and no
  business lock entry changed.
- Cold build and tests: from a newly created `_build/`,
  `./tools/opam exec -- dune build --root . @all` passed and
  `./tools/opam exec -- dune runtest --root . --force` passed under `env -i` with synthetic
  `HOME`/`XDG` directories, without an `OCAMLPARAM` workaround. The retained 5.3.0
  `_build/` stayed inside the backup and was never mixed with the new tree. Compilation and
  test results establish those behaviors; they are not a formal proof of the whole code
  base.
- PTY: `tools/ci-tui-pty _build/default/tui/app/bakhlo_tui.exe examples/book.txt` passed on
  the synthetic fixture at the same four sizes as the stage replay (120×36, 80×24, 48×14,
  32×9), with preview non-publication and byte-unchanged fixture. macOS x86_64 only.
- Formatter: the optional root was recreated at the permanent prefix with the documented
  recipe (`ocaml-system.5.4.1`, `dune.3.24.2`, `ocamlformat.0.29.0`); the wrapper's version
  and pin checks passed. `./tools/format --check` exits 1 with exactly the same 15
  pre-existing source/Dune layout hunks and nested `tui/` config warnings as the captured
  pre-migration 5.3.0 baseline (the unified hunks were compared byte for byte; no
  additional errors), so the gate is red at baseline here too and nothing was
  mass-formatted. This records the state at cutover only; the layouts were brought clean
  later on 2026-10-27 (see the formatting entry above).
- Editor binary: a macOS GUI Emacs smoke under a clean, Finder-like `PATH` opened the real
  tracked `lib/quantity.ml` read-only and selected 5.4.1. The live ocaml-lsp process was
  verified by PID and `lsof` to be the binary inside the main `_opam`, version 1.26. `Z.t`
  hover, Zarith completion and the intentional string-to-int Flymake error behaved as
  expected, with no missing-RPC or inconsistent-assumptions warning; line numbers were on
  and the tool bar off. This checks the real editor binary and project selection, not an
  editor/IDE matrix.
- REPLs: in that same Emacs process, independent project and unrelated study UTop REPLs
  evaluated `Sys.ocaml_version` as 5.4.1 with `OPAM_SWITCH_PREFIX` pointing at the main
  `_opam`, while the study REPL's default prefix was unchanged. `#require "base"` plus
  `Base.Int.(20 + 22) = 42` passed, and leaving the project REPL left the study REPL
  evaluating 42. The synthetic `HOME`/history guards belonged to the test process only.
- Source: the migration changed tracked environment pins/configuration and these documents
  only; application and test source is unchanged.
- Unrun and excluded: Linux CI (`.github/workflows/core.yml`, now pinning 5.4.1) was not
  run, and nothing was committed or pushed. No real household, LOAM, IME or operational
  `.run` data was migrated or accepted. `tools/check` was not used as a wrapper because its
  `privacy-scan` step reads the real copies under `scratch/`; its build and forced-test
  steps were run directly. The formatter vendor's own test suite and ordinary
  source-package `opam install` qualification remain unqualified.

## The application layer is removed (core A, 2026-10-25)

- User decision: with `Daily_book` on book.txt, the application layer (correction
  frontier, reflected-root cuts, Actual source, relations and discharges, current-quantity
  groups and query) and its tests, ports of LOAM's semantic checks, are removed; Git keeps
  them up to `42ce0fc`. The Merchant disposition type moved to `Records`, and the screens'
  date checks use `Book_txt.valid_date`. The domain modules nothing used any more
  (`Event_correction`, `Event_memory`, `Zero_origin_coverage`) went with it.
- 121 files, 79 insertions, 11,362 deletions (application 2,758; tests and models
  8,444; domain 72). The type-boundary cram test keeps its domain checks and now also
  checks that an admitted `Book_txt.book` cannot be built by hand.
- `docs/SEMANTIC_CONTRACT.md` names the core: the book.txt specification plus Bakhlo's
  listed write policies; the parts about correction frontiers, relation discharges and
  presence were updated. `./tools/check` and `./tools/tui --self-check`: pass.

## Daily_book runs on book.txt (core A, 2026-10-25)

- `Daily_book` is now an admitted `Book_txt.book` plus its TXs as entries. Every change
  is one `Book_txt.change` after Bakhlo's write policies, with the refusal reasons the
  screens know; balances, Daily Pace and past-day pools come from the totals the
  admitted book keeps (`Book_txt.quantity`, mutation-checked against the specification's
  balance). The previous implementation, its whole-book reference `Full`, the payload
  and the two-way conversion in `Daily_txt` are gone; `Daily_txt` keeps the roles and
  Attention sections in their text formats. The screens use `Daily_book.quantity` and
  `Daily_book.openings` instead of the application layer's image.
- Before the switch (`ffd019c`), the new core ran next to the old one on the oracle's
  random operations (300 seeds × 30 saves of 1–3 operations, plus re-offering a hidden
  Locus and an overdue plan): both admitted or refused with the same reason, and every
  admitted step left the same book.txt bytes, entries, plans, balances with their
  support, Daily Pace and past-day pools. All 12 mutations of the new core were caught.
- Deliberate differences: `book.txt` refuses a history start without a count, so
  `with_bounded_history` refuses it at once (it used to be accepted in memory and then
  fail to save); the past-day "support conflict" and "count missing" refusals can no
  longer occur. A test entry ID containing a space (invalid in book.txt) was fixed.
- On a scratch copy of the household (removed afterwards; only booleans printed): the
  old core (`ffd019c`) and the new one gave the same 181 answer lines (entry and plan
  counts, every Locus × Measure balance with its support), and the new one prints the
  file's exact bytes. The household Git tree stayed clean.
- Synthetic, this Mac: cold load 1,000 / 10,950 / 45,000 entries ≈ 9 / 100 / 420 ms
  (before ≈ 12 / 168 / 750 ms); save ≈ 49 / 65 / 97–106 ms (45,000: three runs, each the
  median of 21; 90 ms before the switch). `./tools/check` and `./tools/tui --self-check`: pass.

## Presence evidence is removed (core A, 2026-10-25)

- Presence ("nonzero, exact amount unknown", from LOAM) could only come from
  S-expression books: `book.txt` cannot hold it, the migration refused it and the
  household never had any. Removed from `Current_quantity_query` (the presence type,
  its three errors and the `Known_present` answer; `query` now returns the exact answer
  or `Support_unknown`), from `Daily_book` (book data and payload, Daily Pace's
  `daily-pace-balance-amount-unknown`) and from the TUI (Balances state and detail,
  Role Balances lists and the Answerability Map's always-zero `amount-unknown` count,
  Liquidity, Daily Pace, Stock-Flow).
- Tests: the three presence-only query tests are deleted; the support/cut table now
  covers three families (1,024 cases, 256 admitted). Checks that only asserted a
  presence answer are deleted; where they also showed that Merchant, exchange or
  original amounts create no support, they now assert `Support_unknown`. Display checks
  that used a present coordinate use an unsupported one. `./tools/check` (including
  `./tools/tui --self-check`): pass.
- 42 files, 179 insertions, 791 deletions. The Balances state column keeps its width.

## The S-expression book format is removed (core A, 2026-10-25)

- `Daily_book` no longer reads or prints S-expression books (v1–v5 reader, printer,
  entry/plan codec, about 500 lines); its file form is only `book.txt` (`Daily_txt`).
  Every core and TUI test fixture is now `book.txt` text, converted from the former
  S-expression by the former codec itself, so each fixture holds the same book.
  Tests of the S-expression format itself are deleted (`daily_print_tests.ml`,
  version headers, the budget-only schema, `old v1` Merchant); their semantic
  parts stay (exact huge amounts, memo bytes, support families, Merchant and
  original-amount round trips) through `book.txt`. The oracle's cold twin is the
  same facts admitted again (`of_payload (export_payload b)`); the book.txt cold
  reload and the save-changes oracles are unchanged. Presence, which `book.txt`
  cannot hold, is still tested by adding it through the payload (oracle, Daily Pace,
  Balances, Liquidity, Stock-Flow). `store/` and `sexp/` no longer use Parsexp.
- Found while converting: an exchange with a second Effect of a leg's sign in that
  leg's Measure (possible through a correction, not the exchange screen) was saved,
  and its `book.txt` would then refuse the whole book at the next cold load. A save
  and the whole conversion now require every TX to read back as exactly its entry
  (`b6870e0`; test in `test/daily_txt_tests.ml`, mutation-checked). The household
  loads, so it holds no such entry. The Multicurrency Spend fixture's exchange fee
  moved to the source Measure (Daily_book admits extra exchange Effects only in the
  two Measures; book.txt reads a leg as the only Effect of its sign there).
- `./tools/check` and `./tools/tui --self-check`: pass.

## Both UIs compare on copies of the household book.txt (2026-10-25)

- User decision: LOAM reads the shared `book.txt`, so `tools/compare refresh` copies the
  household `book.txt` and `config/` into `scratch/comparison/capture-*/{bakhlo,loam}`
  and `./ui` / `./ui loam` open those copies. Removed: `loam_read/`, `migrate/`
  (the LOAM import), `tools/compare_capture.ml` and their tests (in Git up to `502d570`).
- `./tools/compare self-check` (synthetic): copies are byte-identical, every refresh makes
  a new generation and leaves the earlier one unchanged, a symlinked `book.txt` is
  refused, `clean-copies` keeps only the selected generation.
- Real refresh on the household (read only; its Git tree stayed clean): the Bakhlo copy
  passes `./tools/tui --check`, and the existing LOAM executable's `doctor` accepts the
  LOAM copy (exit 0, no error lines; outputs not kept). The two UIs were not opened.
- `tools/privacy-scan` now also takes the free-text fields of those copies (Locus
  labels and help, memos, Merchants, Attention) that an S-expression book would have
  quoted. Five generic words matched synthetic fixtures and were recorded in the
  ignored baseline after review; `--all`: 1,269 tokens, 454 files, no match.

## A save checks and prints only what it changes (core A, step 1, 2026-10-25)

- Implementation: `Book_txt.book` is an admitted `book.txt` value with its TX index and
  each TX's printed lines. `Book_txt.change` applies changes (add or replace a TX, put
  a plan, set the loci, roles, anchors or Attention) and admits the result with the
  whole-file reader's own code: every line except the untouched TXs is printed and
  read back through the first three stages, and the reference rules (now shared as
  `definitions`, `tx_rules` and `after_txs`) run against the index. Untouched
  reversals of a touched TX are checked again; a change that drops a Locus re-reads
  the whole book. `Daily_txt.changes` turns a save's operations into those changes,
  and `Daily_file` keeps the admitted book in the session and prints it instead of
  converting and re-reading the whole book. Reads fill one buffer of the file's size,
  and the post-save check compares the bytes read back instead of their digest.
- Tests (`./tools/check`, `./tools/tui --self-check`: pass): 64 fixtures unchanged
  (5 admitted, 59 refused, same codes and lines). New: 3,000 generated books with 12
  random changes each, valid and invalid; `change` admits exactly when the whole-file
  reader admits the printed result as the same value, and `print` is that text
  (more than 5,000 batches each way). New oracle: 200 seeds × 30 saves of 1–3
  operations; the changed book.txt equals the whole conversion in value and bytes.
- Mutation checks: turning off the partner recheck, the target-is-a-reversal rule,
  the other-reverser rule, the canonical read-back, the Locus fallback, the head or
  tail checks, the duplicate-TX check or the reverser-index update each fails the
  generated test. In the operation mapping, dropping plan payments, date corrections,
  Merchant, cancellation, loci, anchors, or the order of TXs added in one save each
  fails the oracle. Clauses that no input could reach were removed instead: the
  Measure comparison, a self-reversal check and a reversed-ID check (the partner
  recheck refuses those).
- Measured (synthetic, this Mac, median of 11 saves in one process):

  | Entries | Before | After |
  |---:|---:|---:|
  | 1,000 | 51 ms | 48 ms |
  | 10,950 | 148 ms | 66 ms |
  | 45,000 | about 513 ms | 90 ms |
  | 109,500 | not measured (the whole conversion alone was 914 ms) | 164 ms |

  At 109,500 the remaining time is I/O: checking the file is unchanged (read plus
  MD5, 34 ms), the new revision's MD5, writing with `F_FULLFSYNC` and reading back.
  The ≤100 ms target holds to about 45,000 entries (about 28 years at the household's
  pace), **not at the AGENTS.md ~110k size**. Book_txt reading is 61 → 54 ms at
  10,950 entries; a cold load is unchanged (168 ms at 10,950, 1.9 s at 109,500).
- On a scratch copy of the household (removed afterwards; only booleans and times
  printed): the loaded book prints to the file's exact bytes; a synthetic entry plus
  a count saved through the changes equals the whole conversion in value and bytes,
  and a cold reload equals the session. The first save in a fresh process took
  69–72 ms over 12 runs; later saves in one process take about 49 ms. The household
  itself was only read (digest unchanged).

## LOAM reads and writes the shared book (2026-10-25)

- Implementation: LOAM's `BookTxt` codec and `BookTxtBridge` now connect the
  shared file to its existing household/TUI publishers. Current corrections
  collapse to stable root IDs; scales, labels, roles and Attention stay inside
  the book. Legacy household generations retain their own format and behavior.
  The common specification's stale “not migrated / no LOAM implementation”
  introduction was updated. No household data was accessed or migrated here.
- Build: `lake build loam loamTui Loam.DurableProofs` passed on macOS x86_64.
  This checks the existing durable proof surface, not a new formal proof of
  the shared codec. Broader research-model replay was not run.
- Tests: LOAM `lake test` passed, including native `bookTxtChecks`. The shared
  corpus passed all 64 cases (5 accepted, 59 refused): exact refusal code/line,
  canonical bytes, expected quantities, actual LOAM quantity projection, and
  unrelated Attention mutation followed by cold reload.
- Synthetic native scenarios passed: record/correction/date/merchant/reversal,
  plan creation/cancellation/completion/batch/continuation, metadata ownership,
  used-scale refusal (including original amounts), immutable common yearly
  checkpoints, stale/busy writers, malformed/missing-current recovery, symlink
  refusal, stale-stage cleanup and same-inode previous-link cleanup. Exchange
  checks include zero-net additional Measures, explicit-key collisions,
  duplicate physical postings and anonymous reversals.
- Runtime smoke: the real LOAM CLI recorded a synthetic movement, the real
  Bakhlo store loaded and rewrote its exact canonical bytes, then LOAM's
  `doctor` accepted the cold reload. The actual two writers excluded each other
  in both directions and reacquired after release. LOAM's native PTY displayed
  an in-book transaction and labels; Actual, Scheduled, Balances, resize,
  return and Calendar → launcher → quit were exercised on synthetic data.
- Launcher regression: `tests/test_launcher_build_check.py` passed all 19 tests;
  shared native-source changes now invalidate its cached build receipt.
- Not executed: real-household acceptance/cutover, Linux runtime, physical
  power-loss testing, commits or pushes. The LOAM data-directory default is unchanged.
- Committed later as LOAM `c8cd0d3c` by a second pass that re-ran, on macOS x86_64,
  the build, `lake test` (exit 0), `./tools/test-product common-format`, the 64-case
  corpus and the launcher tests. That pass replaced two synthetic test labels that
  LOAM's privacy guard refused. LOAM CI does not run.

## Household migrated to book.txt (2026-10-25)

- User-approved. With no TUI running and both repositories in step with their remotes,
  `book-txt-storage` was fast-forwarded into `main` and pushed, then `./tools/book-txt migrate`
  ran on `../bakhlo-data`: conversion and comparison, book.txt written under the writer lock,
  read back through the store and compared again (every entry, plan and coordinate equal,
  reprint identical), and one commit replacing `book.sexp`, `config/accounting-roles.tsv` and
  `attention.loam`, pushed to the private backup. `./tools/tui --check` admits the book.
- Not executed: opening the migrated household in the TUI; the user does that next.
- Rollback: revert the household commit (the parent holds the S-expression book and its
  sidecars) and revert the stage 4b commits on `main`; no force push.

## The store reads and rewrites book.txt (stage 4b, 2026-10-25)

- Branch `book-txt-storage` (not `main`). `Daily_txt` converts Daily_book <-> book.txt;
  `Daily_file` loads only book.txt and publishes by rewriting it whole (temporary file,
  `F_FULLFSYNC`, `.prev`, rename, directory flush, bytes read back). The session keeps the
  in-memory book. Roles and Attention are book sections saved through the same writer.
- `test/daily_book_oracle_tests.ml`: every mutation of a book.txt-loaded book equals its
  book.txt cold reload (200 seeds x 30 steps, none refused by book.txt). Found and fixed on
  the way: an added Locus now gets a label row, an empty memo is no memo, a reversal is not
  balance-checked (an exchange's reversal is not balanced), Effects keep their keys.
  Removing the empty-memo normalisation fails the oracle.
- `test/daily_txt_tests.ml`: the 5 accepted fixtures, 2,000 generated books and a converted
  synthetic household reprint to the same bytes through Daily_book with equal answers.
- `test/daily_file_tests.ml`, `tui/scenarios/recovery_checks.ml`: three checkpoints by
  injected fault and by SIGKILL leave the old or the new book (a landed save is confirmed
  and never retried), a refused temporary file and a held writer lock write nothing, one
  `.prev` and no temporaries after a normal save, roles and Attention read back as written,
  an S-expression book is refused unconverted.
- `./tools/check`, `./tools/tui --self-check` (37 PASS lines), the PTY smoke on
  `examples/book.txt` and `./tools/compare self-check` passed.
- Publish timing (synthetic, `scratch/save-format-probe`, median of 7): 60 ms at 1,000
  entries, 163 ms at 10,950, 513 ms at 45,000; under 100 ms on a household-size copy. Before
  keeping the in-memory book it was 75 / 348 / 1,347 ms. Converting and re-admitting the
  whole book on each save is what grows; the core work (A) is to remove it.
- `./tools/book-txt migrate` rehearsed on a local clone of the household in scratch: book.txt
  written, read back through the store and compared equal, one commit replacing book.sexp,
  `accounting-roles.tsv` and `attention.loam`; `--check` admits the result. Not executed:
  opening the migrated household in the TUI (the PTY smoke accepts only the synthetic
  fixture), and the real migration.

## Household copy converts to book.txt with every answer equal (2026-10-25)

- `migrate/daily_to_book_txt.ml` converts a household (`book.sexp` with appended records,
  `accounting-roles.tsv`, `attention.loam`) to `Book_txt`. It prints and re-admits the
  result, then compares it with the source `Daily_book`: same entries in recorded order
  (id, date, memo, Effects, reversal, original amount, Merchant, exchange), same plans, and
  an equal current quantity at every coordinate named by an Effect or support line
  (`Current_quantity_query` against `Book_txt.balance`, two separate implementations).
- `test/daily_to_book_txt_tests.ml`: a synthetic household with an empty memo, reversal,
  original amount, Merchant, three plan endings, unlabelled and non-approved loci, a
  non-prefix reflected cut (becomes `ANCHOR` + `ALSO`), an empty cut (`ANCHOR -`) and
  bounded history converts with the expected text; settlements, presence with
  coordinates, a bad roles header, a role on `suspense` and an Effect key outside an
  exchange each refuse. Mutation: dropping ALSO in the conversion refuses with
  `balance-differs:wallet/jpy`.
- `./tools/book-txt trial` on the latest household copy (scratch only): conversion and
  comparison succeeded for every entry, plan and coordinate, the three anchors became
  pointers without ALSO, and the household files were byte-identical before and after.
  Counts, names and timings stay in the ignored trial directory.
- The household is still `book.sexp`; nothing was migrated. `./tools/check` and
  `./tools/tui --self-check` passed.

## Common format reader and printer against the conformance fixtures (2026-10-25)

- `book_txt/` (`Bakhlo_book_txt.Book_txt`) reads and prints the line-based `book.txt`
  of `docs/COMMON_FORMAT.ja.md`. It is pure, depends only on Zarith and is not yet
  used by the household path (no `Daily_book` mapping, migration or store).
- `test/book_txt_tests.ml`: all 58 fixtures in `test/common_format/` behave as
  `cases.tsv` lists. Each of the 3 accepted books reprints to its exact bytes and gives
  every `.answers` balance; each of the 55 refused books gives the listed code and line.
  10,000 generated books (awkward escaped memos, Merchant, ORIGINAL, plans, ANCHOR with
  ALSO, HISTORY-FROM, ATTENTION) read back equal and reprint to the same bytes.
- Mutations, each reverted: treating ALSO as empty in `balance` fails the fixture test
  (`wallet jpy: want 1120, got 1000`); dropping ALSO lines from the printer fails the
  generated round trip. `./tools/check` and `./tools/tui --self-check` passed.
- Not executed: comparison with the household data, a LOAM (Lean) implementation, and
  any timing of this printer against the earlier probe.

## Terminal series colours: yellow instead of red, as in LOAM (2026-10-24)

- User choice after the previous change: red stood out too much; a yellowish
  third series, as in LOAM, is preferred. The Terminal slots are now blue,
  magenta, yellow, cyan, so three series are blue, magenta and yellow; no red or
  green slot remains. This reverses the earlier rule that yellow washes out on
  a light background, by the user's own reading. Bakhlo themes unchanged.
- The checks now require series 3 to be yellow and no slot to be red or green;
  they fail on the previous order. `./tools/check` and `./tools/tui --self-check`
  passed. Not checked on the user's physical terminal.

## Terminal series colours keep blue apart from cyan (2026-10-24)

- User report after the Trend change: the bluish and the greenish series were
  hard to tell apart. In the Terminal theme the slots were blue, magenta, cyan,
  red, so the three default series were blue, magenta and cyan. Cyan is now the
  fourth slot: three series are blue, magenta and red (still no yellow and no
  red/green pair). The Bakhlo themes' indexed colours are unchanged.
- A check requires series 3 to be red and none of the first three to be cyan; it
  fails on the previous order. `./tools/check` and `./tools/tui --self-check`
  passed. Not checked on the user's physical terminal.

## Trend looks and scrolls like LOAM (2026-10-24)

- User report: the Trend / Locus report looked and scrolled nothing like LOAM's.
  One fresh `./tools/compare refresh` generation, Bakhlo (native build of this
  commit) against the existing LOAM executable (`../loam` `19f7d319`, built
  2026-10-20, SHA-256 prefix `4a413fa3df08c149`), macOS x86_64, i5-8259U.
- Causes of the weight, found by sampling the TUI while scrolling: every key and
  every one of the Shell's several view calls per frame projected the whole
  report again (default series scan plus the projection), and the Notty renderer
  found each cell's span style by re-measuring the row's spans from the start
  (quadratic in a coloured chart row). The Day window also re-centred on every
  key, so the whole chart slid one column per key.
- Changes: the owner keeps the projection it painted and reuses it only while
  the book is the same value and the boundary text, roles, Measure and query are
  equal (any change projects again; `Enter` drops it); the view projects inside
  its lazy rows only. The renderer measures each span once per row. The layout
  follows LOAM `LocusTrendComparePane`: no frame; heading; two-row series rack;
  source line; `Selected` line (a running window ends on the observation day, a
  full one names its exclusive end); one value row per series; plot with an
  eight-cell value axis (wider when a tick label needs it); period axis (Day:
  first day, selected day, `As of`; Cycle/Month: each window, or the two ends
  when a window is under eight cells); overlay marker row A/B/C and legend;
  flowing footer tokens; LOAM's compact layout at 14 rows or fewer. The selected
  markers win over the line and two in one cell become `◎` (they were hidden
  whenever the line passed through, which was nearly always); the Day window over
  all history moves only when the selection leaves it.
- Intentional differences: an axis label that would touch a higher-priority one
  is left out (LOAM overwrites it, e.g. `Sep 29t 1`); a missing value stays
  `(unavailable)` and an amount that does not fit says `exact value: enlarge
  terminal`, never clipped digits; amounts keep Bakhlo's `564 jpy/day` format;
  the zero-based value axis and the coverage note in `?` stay; overlapping lines
  keep both series' dots. Pointer scrub is still absent (no mouse coordinates in
  `Ui_input`); the plot is one or two rows shorter because the Shell keeps its
  feedback row.
- PTY timing (driver of the 2026-10-23 paired-speed entry, 15 `←` in Day after
  `]]`, last redraw byte, median of 45 keys over three rounds; the renderer-only
  row is one round of 15):

  | `←` in Trend Day (ms) | 120×36 | 80×24 |
  | --- | ---: | ---: |
  | Bakhlo before | 36.0 | 25.9 |
  | Bakhlo, renderer fix only | 28.4 | 23.9 |
  | Bakhlo after | 13.7 | 7.0 |
  | LOAM | 17.9 | 7.9 |

- Owner CPU (disposable runner, one `←` then one view with rows forced, median of
  21, 120×36): latest-data copy (791 entries) key 2.63 → 0.09 ms, view 8.58 →
  4.90 ms; synthetic plain 109,500 entries (Day, ~29k points) key 334 → 0.07 ms,
  view 387 → 3.4 ms. Opening Trend or changing grain/scope/series still projects
  once: ~150 ms (Cycle) and ~357 ms (Day) at 109,500 entries, unchanged.
- Captures at 120×36, 80×24 and 48×14 of both programs (Cycle, Day, moves,
  overlay) match apart from the differences above. Checks: frameless rows fill
  the width, rack and per-series value styles, marker over line, `◎`, the
  window kept inside and moved by one when leaving, Selected/As of lines, label
  omission, re-projection for a changed book, boundary text and roles; each new
  check fails against a mutation of the rule it covers. `./tools/check` and
  `./tools/tui --self-check` passed; the copy's book and config bytes were
  unchanged, the AI's processes closed and `./tools/compare clean-copies` run.
  No physical-terminal, IME or human acceptance.

## Performance documentation commit review (2026-10-23)

- Documentation only: retained the synthetic investigation's original revisions
  and measurements, and distinguished them from the Actual optimizations already
  shipped in `7a7dc9e`. The study, handoff and pending tasks now describe those
  optimizations as implemented, not as future work. No product code, dependency,
  configuration or book format changed.
- `./tools/check`, `./tools/tui --self-check` and `./tools/privacy-scan --all`
  passed. No new benchmark, latest-data paired comparison, physical-terminal,
  IME, P7 or power-loss check was executed in this documentation review.

## Daily Pace What-if prices a +income (2026-10-23)

- Bakhlo addition to the What-if overlay (`tui/screens/pace/daily_pace_what_if.ml`):
  a leading `+` prices an immediate income into the selected pool
  (`floor((available + amount) / days)`), shown as `Income (JPY)` and `After income`.
  `-` or no sign stays LOAM's purchase; unsigned input paints exactly as before
  except the hint and first footer line, which now mention `+income`. A sign is
  accepted only as the first character; at most 18 digits follow. Nothing is written.
- Synthetic checks: on the one-day sample pace with 500 jpy available, `+200` gives
  700/day and 700 available, `-200` and `200` give 300/300, and `+`, `+-200`, `--200`
  are refused (`daily-pace-what-if-signed-income-and-purchase`); typing `+2000+`
  paints `Income (JPY): +2000`, `After income:`, Available after and the input notice,
  with no `After purchase` (`daily-pace-what-if-prices-income`). `./tools/check` and
  `./tools/tui --self-check` passed.
- **Latest-data paired comparison not executed**: LOAM has no income What-if to
  compare, and the unsigned path's calculation is unchanged. Human/IME acceptance not
  executed.

## Household trial saves and backup restore drill (2026-10-23)

- User request: before relying on today's changes daily, try saving on a copy of
  the household and drill restoring the private backup. Code at `0ffe5b3`.
- Trial saves: `Daily_file.restore_copy` made a byte-identical copy of
  `../bakhlo-data/book.sexp` (with its appended records) in ignored scratch. A
  scratch program used the TUI's single writer (`Daily_file.append`, full sync) to
  save a memo correction, a date-only correction, a Merchant classification and a
  new entry, choosing targets the book admits and printing results only. After
  every save the book equalled a cold reload of the file and the whole-book
  reference (`Daily_book.Full`), on the printed book and every coordinate's
  answer. Saves took 20.6–20.8 ms (33.3 ms for the first), almost all the drive
  flush. Compaction then kept the same book, reloaded cold with no records and
  left `.prev` equal to the file before; `--check` passed on the result. The
  household file was unchanged.
- Restore drill: the backup `shumoku88-bit/bakhlo-data` is private. A fresh clone
  from GitHub had the household's HEAD and history; all tracked files (book,
  attention, config, notes) were byte-identical to `../bakhlo-data`, which was
  clean and pushed. `--restore-copy-from` the cloned book to a fresh file gave a
  byte-identical book that passed `--check` and `--inspect-recovery` (no
  interrupted save). Every backed-up version of `book.sexp` in the history
  passed `--check` (8 of 8). Locks, `.prev` and `.DS_Store` are not backed up by
  design (`.gitignore`).
- Afterwards the household repository was unchanged and clean; the clone, restored
  and trial copies were deleted. The program and its output are in ignored
  `scratch/trial-save-2026-10-23/`. Not covered: a restore onto another machine,
  a power cut during a save (P7) and real terminal or IME use.

## Daily Pace opens faster (2026-10-23)

- User request: make opening Daily Pace faster (it was 23.7 / 21.7 ms at
  120×36 / 80×24 on the latest data, under LOAM's ~135 ms but above the 16 ms
  key target). Causes found by sampling: the Shell builds a route's view several
  times per frame (body, footer, cursor), and every Daily Pace view computed
  today's pace and all trend samples twice for a subtitle the Workspace layout
  never paints; each sample day re-scanned every entry for the past pool; each
  paid plan's entry was found by a linear search, per day.
- Changes: one view computes today's pace and the samples once, lazily, only for
  the painted rows (overlays reuse the same pace); the subtitle is `Hidden`, and the
  checks that read it now read the painted summary row. Core
  `Daily_book.pools_at_end_of_days` answers many days from one pass (each
  coordinate's total and its sums by day after the earliest day asked);
  `pool_at_end_of_day` is its one-day case, so there is one implementation. Paid
  plans use `find_entry`.
- CPU of one Daily Pace view with forced rows (native runner, median of 9 or 41,
  before = `7a7dc9e` from a clean worktree; one-Measure “plain” books with a
  wallet pool and monthly boundaries; the latest-data copy prints timings and
  digests only). This runner calls the view once, so it does not include the
  removed per-frame repeats:

  | Daily Pace view (ms, 120×36 / 80×24) | before | after |
  | --- | ---: | ---: |
  | plain 3,000 | 18.1 / 17.0 | 6.1 / 5.3 |
  | plain 10,950 | 57.1 / 56.6 | 11.9 / 10.6 |
  | plain 109,500 | 714.5 / 733.8 | 108.0 / 110.0 |
  | latest-data copy | 7.7 / 7.0 | 1.9 / 1.2 |

- Latest data, PTY (method of the
  [paired speed](#paired-speed-bakhlo-and-loam-on-the-latest-data-2026-10-23)
  entry, five alternating rounds, one fresh generation): `d` from Home to the last
  redraw byte fell from 23.7 / 21.7 ms to 9.5 / 6.6 ms; LOAM measured
  133.9 / 129.7 ms in the same rounds.
- Output unchanged: a before/after sweep of the Daily Pace owner (five key scripts
  over days, all five periods, view styles, details, Why, What-if and Target; four
  sizes) compared digests of title, rows, footer, overlay, cursor and request:
  200 identical steps on the latest-data copy (120 distinct painted states) and on
  two synthetic books. Making paid-plan lookup fail changed 180 of the
  latest-data steps. A Core test checks that unordered days with a refused date
  answer as one day each, for zero-origin, bounded and missing-support pools; it
  fails when the earliest day is not used.
- `./tools/check`, `./tools/tui --self-check` and `tools/ci-tui-pty` passed. LOAM
  original hashes were unchanged; the driver's leftover processes were closed and
  the copies cleaned. Runners, books and raw results are in ignored
  `scratch/pace-open-2026-10-23/`. No IME, physical-terminal or human claim.

## Actual All view: faster list moves (2026-10-23)

- User request after the paired measurement: make moving in Actual's All view
  faster. Changes in `actual_workspace.ml`, all removals of repeated work:
  each day's EXPENSE total and each list row's text are built only when shown;
  one key resolves the list once (the move and the kept view share it, through a
  value local to that key, no stored cache); the amount column's scan stops once
  the widest possible width is reached; the Loci list uses a hash set instead of
  `List.mem`. An integer-day sort key was tried and reverted (no measured gain).
- CPU (the native `Actual_screen` runner another worker left in ignored
  `scratch/actual-perf-20261023-ActualCPU/`,
  80×24, Down then forced rows, median of nine after warm-up, before = `af04ab5`
  from a clean worktree). “probe” books are the three-Measure startup-probe
  fixtures (occasional 180-bit amounts); “plain” books are one Measure with
  ordinary jpy amounts, where the amount scan cannot stop early.

  | All, key + paint (ms) | before | after |
  | --- | ---: | ---: |
  | probe 1,000 | 9.6 | 1.2 |
  | probe 10,950 | 86.8 | 25.0 |
  | probe 109,500 | 1,056.3 | 292.5 |
  | plain 3,000 | 17.1 | 5.0 |
  | plain 10,950 | 72.2 | 27.7 |
  | plain 109,500 | 841.9 | 342.9 |

  Month windows also fell (plain 109,500: 16.4 → 11.1 ms). The 109.5k 16 ms
  target is still not met: the window scan, the full sort and, for ordinary
  amounts, the amount scan remain linear per paint.
- Latest data (one fresh comparison generation, the PTY method of the
  [paired speed](#paired-speed-bakhlo-and-loam-on-the-latest-data-2026-10-23)
  entry, five alternating rounds): `j` in All fell from 18.2 / 16.3 ms to
  8.8 / 7.3 ms at 120×36 / 80×24; LOAM measured 12.6 / 8.3 ms in the same rounds.
  The Cycle view stays at 6.6 / 4.5 ms. LOAM original hashes were unchanged, no
  process remained and the copies were cleaned.
- Output unchanged: a before/after sweep through `Actual_screen` (three synthetic
  books including mid-width, capped, CJK, split, multi-Measure and role-less
  amounts; two `today`s; five sizes 120×36 to 20×6; ten key scripts covering
  moves, panes, Loci, sorts, search, All/Month/Year/Day, `[ ] { }` and Details)
  compared 3,540 digests of title, rows, footer, overlay, cursor, request and
  state: all identical. A width-boundary mutation changed 20 of them, hiding day
  totals 1,439. A new check pins the amount column to the widest amount of the
  whole list (off screen, capped) and an off-screen day's total; it fails when the
  scan is limited to the first rows.
- `./tools/check`, `./tools/tui --self-check` and `tools/ci-tui-pty` passed.
  Runner, books, sweep and raw results are in ignored
  `scratch/actual-all-nav-2026-10-23/`. No IME, physical-terminal or human claim.

## Paired speed: Bakhlo and LOAM on the latest data (2026-10-23)

- User request: compare the two programs' speed on real data. One fresh
  `./tools/compare refresh` generation (frozen LOAM record, read-only copy) opened by
  both: Bakhlo `edbcc63` (native, `_build/default/tui/app/bakhlo_tui.exe` on the
  comparison book) and the existing LOAM executable (`../loam` `19f7d319`, binary
  built 2026-10-20, SHA-256 prefix `4a413fa3df08c149`, `loam tui` on `loam-view`).
  macOS x86_64, Intel i5-8259U.
- Method: a scratch OCaml driver ran each program under `script(1)` at 120×36 and
  80×24 with `TERM=xterm-256color`, sent keys from Home and timed each key from the
  write to the last output byte of its redraw (a redraw ends after 400 ms of
  silence; startup after 1 s). Five rounds per size, alternating the programs; the
  table is the median over rounds and repeated keys. Screen bytes were not kept or
  read. The terminal emulator's own painting is not included. Startup includes
  ~22 ms of harness time (`script`, `sh`, `stty`), measured with a trivial command.
  Bakhlo's Actual opens on the current Cycle; it was moved to All through `f` for the
  All row, which is LOAM's default Actual view.

  | ms (120×36 / 80×24) | Bakhlo | LOAM |
  | --- | ---: | ---: |
  | Startup to first full Home | 51 / 51 | 242 / 246 |
  | `a` open Actual | 7.6 / 5.9 | 11.4 / 8.8 |
  | `j` in Actual, Cycle | 7.0 / 4.5 | — |
  | `j` in Actual, All | 18.2 / 16.3 | 11.3 / 7.5 |
  | `b` open Balances | 5.2 / 2.6 | 75.7 / 75.4 |
  | `d` open Daily Pace | 24.2 / 19.5 | 153.8 / 148.0 |
  | `Esc` back to Home | 1.5 / 1.4 | 102.9 / 102.4 |

- Findings: Bakhlo starts about 4.7× sooner and opens Balances and Daily Pace
  several times faster. Moving in Actual's All view is slower in Bakhlo and at
  this household's size is already at or above the 16 ms key target, while the
  Cycle view stays under it. LOAM's `Esc` waits ~100 ms on every return, which
  looks like an escape-sequence timeout rather than computation (not confirmed in
  LOAM's source). A trial LOAM launch before the rounds, its first after the refresh, took 2,079 ms
  (probably loading its 111 MB binary) and is not in the table; the Bakhlo trial launch took 49 ms.
- Afterwards: SHA-256 of every `../loam-data` file outside `.git` was identical
  before and after; no driver process remained; `./tools/compare clean-copies`
  passed. Driver source, per-run results and the original hashes are in ignored
  `scratch/perf-paired-2026-10-23/`. Read-only flows only; no writes, IME, human
  acceptance or physical-terminal timing.

## Actual CPU baseline and bounded width experiment (2026-10-23)

- Historical baseline, before the Actual optimizations in `7a7dc9e`. The
  bounded-width scan, one resolution per key and visible-row formatting have since
  shipped; current integrated results and frame comparisons are in
  [Actual All view: faster list moves](#actual-all-view-faster-list-moves-2026-10-23).

- Investigation only: no product code or storage/configuration changes in this
  pass. The measured Actual baseline reports revision
  `edbcc63fb9b06986c6aa7859b5a92d12f7f84de1` (including the entry-map change below),
  Darwin x86_64, OCaml 5.3.0. Runner and relevant source SHA-256 values, environment
  and raw baseline results are in ignored
  `scratch/actual-perf-20261023-ActualCPU/`.
- Executed the native `Actual_screen` runner successfully: 80×24 terminal geometry,
  79×20 content; three-Measure synthetic startup-probe fixtures, including splits,
  reversals and occasional 180-bit quantities. All and the last calendar Month
  were chosen through the public period picker. Loading, picker setup and initial
  entry-list forcing were outside timing. Two warmups, then nine calls from the
  same initialized state; each call handles Down and forces `view.rows`.

  | Book entries | Window (entries) | Key median ms | Paint median ms | Combined median ms | Allocated MiB, key / paint |
  | ---: | --- | ---: | ---: | ---: | ---: |
  | 1,000 | All (1,000) | 1.516 | 4.702 | 6.079 | 1.66 / 4.82 |
  | 1,000 | Month (100) | 0.157 | 0.472 | 0.629 | 0.17 / 0.54 |
  | 109,500 | All (109,500) | 382.457 | 720.461 | 1,147.071 | 212.67 / 553.78 |
  | 109,500 | Month (310) | 11.940 | 12.628 | 25.087 | 0.50 / 1.57 |

- Combined is the median of each call's key + paint, not the sum of the two
  independent medians. Allocations are cumulative transient allocations per call,
  not live heap, RSS or proof of a leak. Paint includes owner `view`, footer/cursor
  construction and forced rows, but not Shell composition, Notty image creation,
  terminal I/O or PTY latency. This workload is not the earlier two-Locus
  `234.804 ms` benchmark; the difference is not a measured regression.
  The "before" row in
  [the integrated comparison](#actual-all-view-faster-list-moves-2026-10-23) is
  a later, independent run of the same runner, fixture and warm-up method at
  `af04ab5` (documentation-only over `edbcc63`); its median differs despite
  identical output. Use that comparison's paired measurements for the improvement,
  not this earlier baseline combined with its "after" row.
- Executed a separate, disposable width-only experiment over the same synthetic
  fixtures. It copies the current private `amount_summary` faithfully and compares
  the current full fold with an early exit at
  `cap = min 22 (max 0 (row_width - 26))`. For `cap <= 12`, the clamp's result is
  already fixed and no entries need visiting.

  | Width scan, 109,500 entries, row width 74 | Current | Early-exit candidate |
  | --- | ---: | ---: |
  | Time, median of 9 after warmup | 83.1969 ms | 0.5429 ms |
  | Allocated MiB, separate call after compaction | 67.31 | 0.51 |
  | Entries visited | 109,500 | 823 |

- The width result agreed for empty, huge-first, huge-last and ordinary-only lists
  over row widths 0–200, and for both full fixtures at widths 10/35/50/74/114.
  Ordinary-only and huge-last cases still visited every entry at cap 22: worst-case
  O(N) remains. The scan is an isolated candidate, not an integrated UI speedup;
  its time cannot be subtracted from the owner baseline as a proven improvement.
  Source and selected observations: `width_perf.ml`, `selected_observations.txt`
  in the same ignored directory.
- Executed a separate date-correction + lazy-list experiment on 109,500 synthetic
  entries (three warmups, median of 21): mutation 0.011 ms; first `B.entries`
  7.895 ms and 2.506 MiB allocated; cached `B.entries` 0.001 ms; mutation + first
  list 7.909 ms. Recorded order, replaced date, original-book immutability and
  cached-list identity assertions passed. This is not a save-to-repaint timing.
  Source: `scratch/startup-probe-pjl2w0/list_cost.ml`; selected observations are
  retained with the Actual experiment. The entry-map change removes list work
  from mutation, but not the consumer's eventual full list materialization.
- `./tools/startup-probe 1000 109500` also completed on the reviewed entry-map
  working tree; evidence is `scratch/startup-probe-pjl2w0/`. Its three modified
  Core/overlay source hashes agreed before and after the run. These three-Measure
  measurements are distinct from the paired one-Measure correction study below.
- Proposals at the time of this investigation: integrate the bounded-width scan first, then reduce
  repeated resolution and format only visible rows. Month's remaining full-book
  range scans need separate profiling; a date index does not shrink All's result.
  No prototype of those broader changes, Core/TUI suite, full-frame comparison,
  actual terminal/IME, household comparison or save-to-repaint test was executed
  in this investigation. No new acceptance or durability claim.

## Entry corrections without rebuilding the entry list (2026-10-23)

- Cause: `Daily_book` kept its entries as one recorded-order list, so every in-place
  correction (replacement, date-only correction, Merchant classification) rebuilt the
  whole list. At 109.5k synthetic entries each correction allocated ~326k words and
  promoted almost all of them to the major heap, which is why its time grew faster
  than the entry count (×480–680 for ×109.5 entries).
- Change: the recorded order is a map from position to entry (newest first, so one
  fold builds the oldest-first list) with an ID → position map; a correction replaces
  one node, and a new entry extends an already built list. Storage format, `.mli` API
  and every answer are unchanged. `entries_rev` is now O(N); its one TUI caller
  (represented coordinates, order-insensitive) uses `entries`.
- Timing (synthetic one-Measure book, native, in-process; each operation the median of
  41 calls on the same base book; the table is the median of three runs alternating
  with `624f40a` built from a clean worktree). “+ list” also builds `B.entries` of the
  result, as the TUI does after a save. Bench source, raw runs and environment are in
  ignored `scratch/entry-replace-map-2026-10-23/`.

  | 109.5k entries (ms) | before | after |
  | --- | ---: | ---: |
  | Replace existing entry | 4.841 | 0.003 |
  | Correct entry date | 4.700 | 0.001 |
  | Classify merchant | 4.679 | 0.001 |
  | Replace + list | 9.694 | 4.431 |
  | New entry + list | 3.081 | 3.234 |
  | `of_string` load (median of 5) | 1,479.6 | 1,460.1 |
  | Reachable book heap (MiB) | 90.7 | 93.2 |

  At 36.5k: replace 0.348 → 0.003 ms, replace + list 1.934 → 0.534 ms. Per
  correction at 109.5k: ~1.8k minor words and no promotion (was ~326k promoted).
  The remaining O(N) cost is building the entry list the TUI reads after a save.
- Checks: `./tools/check`, `./tools/tui --self-check` and the PTY smoke
  (`tools/ci-tui-pty`, four sizes) passed locally. The `Full` / cold-reload oracle
  (`test/daily_book_oracle_tests.ml`, which compares `to_string` order, balances and
  Daily Pace) fails on two deliberate mutations — a correction written one position
  off and a new entry put first — and passes on the change.
- Not executed: TUI save-to-repaint timing, the optional formatter (not installed),
  household data or latest-data paired comparison (no displayed answer changes; the
  oracle covers agreement). No P7, power-loss or human acceptance claim.

## Performance and GADT investigation (2026-10-23)

- Historical investigation at `624f40a`, before the entry-map and Actual
  optimizations. See [entry corrections](#entry-corrections-without-rebuilding-the-entry-list-2026-10-23)
  and [Actual All view](#actual-all-view-faster-list-moves-2026-10-23) for the
  subsequent product changes; the measurements below remain the original results.

- Research and documentation only; no product code, configuration or storage format
  changed. Recommendations and remaining measurements:
  [performance and GADT study](PERFORMANCE_AND_GADT_STUDY.ja.md).
- Executed `./tools/startup-probe 1000 109500` successfully on measured revision
  `624f40a9c18f20a7b539230b6165d5eb68b7d317`, macOS x86_64, OCaml 5.3.0.
  Synthetic evidence stays in ignored `scratch/startup-probe-xORcT7/`
  (`environment.txt`, `results.txt`). Performance measurements used synthetic
  inputs only; no household originals were accessed.
  Filesystem caches were not flushed; the probe's separate-process “cold” loads
  are not uncached disk measurements or complete TUI startup measurements.

  | Measurement | 1,000 entries | 109,500 entries |
  | --- | ---: | ---: |
  | Parsexp parse only, single timed call | 7.946 ms | 943.494 ms |
  | `Daily_book.of_string`, single timed call | 21.653 ms | 2,031.585 ms |
  | Separate-process S-expression load, median of 3 | 27.422 ms | 2,330.027 ms |
  | Separate-process experimental Marshal load, median of 3 | 5.441 ms | 199.161 ms |
  | Reachable book heap after compaction | 0.9 MiB | 99.7 MiB |
  | Reachable query image / entries list | 0.7 / 0.4 MiB | 80.4 / 42.2 MiB |
  | Replace existing entry, median of 21 | 0.0091 ms | 5.2531 ms |
  | Correct entry date, median of 21 | 0.0060 ms | 5.5668 ms |
  | Classify merchant, median of 21 | 0.0060 ms | 4.4470 ms |
  | Append and full durable sync, median of 21 | 22.2549 ms | 20.9599 ms |

- Heap figures count reachable OCaml words, not RSS or allocation rate. The image
  and entries share objects: their sizes are not additive. No string-ownership,
  per-type heap, promotion or GC-pause profile was collected.
- The experimental snapshot load remains above the 100 ms target at 109,500
  entries. The probe asserts one balance agrees after an in-memory Marshal
  round-trip; it does not qualify a production cache, invalidation, log replay or
  all semantic answers. Startup optimization remains deferred by the user.
  Replacement and date correction exceed the 5 ms work target in this run;
  durable-save timings include drive-cache flush and do not isolate CPU save work.
- Source inspection at the measured revision: Actual sorted resolved records, formatted the whole
  transaction list before selecting visible rows, scanned global amount widths and
  repeated resolution during navigation. `B.entries` is in recorded, not date,
  order. A date-range index cannot reduce the selected set for All (`K = N`).
  The earlier [All benchmark](#actual-render-local-reuse-and-empty-query-search-2026-10-21)
  and [period-picker timings](#actual-period-bar-and-picker-2026-10-22) use different
  workloads and statistics; neither is a current remeasurement.
- Type inspection: `screen_registry.ml` already uses an existential GADT to pair
  each screen state with its functions. `Current_quantity_query` already separates
  abstract `exact` and `present` payloads, with `quantity : exact -> Quantity.t`.
  The proposed outcome GADT supplies no demonstrated additional guarantee or speed
  improvement for that boundary. Operation tags alone do not establish validity
  against the current book.
- Documentation privacy check: `./tools/privacy-scan --all` completed with no
  matches. The scanner reads ignored private copies internally without emitting
  their text; those copies were not used as performance inputs.
- Not executed in this investigation: Actual key/paint remeasurement, optimization
  prototypes, Core/TUI tests, PTY/IME or latest-data paired comparison. No claim of
  performance improvement, human acceptance, P7 or power-loss qualification.

## Actual list keeps its view while the selection moves (2026-10-22)

- User request: moving back up from the end of the Actual list kept the selection on the bottom row and slid the whole list each step. The workspace now keeps the first shown row of the Loci and Actuals lists and moves it only when the selection would leave the view (then it brings the selected day's header in when the whole day fits, as before). Only keys that change the list update it, so opening a day and returning restores the state exactly; a period change starts at the top.
- Checks (synthetic): from the end, one and three moves up keep the first shown row while the selection moves; forty moves scroll; a move down inside the view keeps it. The check fails with the view update disabled and passes now. `./tools/check` and the PTY smoke passed locally; a tmux capture at 80×24 on a synthetic book showed the view held for six moves and scrolling at the top. No household data was accessed.

## Actual period bar and picker (2026-10-22)

- User choice 2026-10-22 (with the Calendar removal): the Actual's top row is a period bar ` Actual  Day [Cycle] Month Year All  2026-09-25..10-24  Expense 97,173 jpy` (current period bracketed and bold; a cycle names its last day, not the exclusive end; narrower bars drop the other periods, then the window, never the amount). `f` opens a picker over the list: every window of the period, newest first, with its entry count and EXPENSE total (the whole window, not the search or Locus filter), `now` on the window containing today; `h/l`/Tab change the period, `j/k`/PgUp/PgDn/Home/End move, Enter opens the window (today inside it, else its last day, is the focus), Esc/`q`/`f` close. Months and years span the ledger, today and the current window; days are those with entries and today; cycles are the configured preset (`Period_window.cycle_windows`, now also used by `resolve`). A missing cycle shows its reason and Enter refuses. The picker is modal (Space does not open Commands) and a reload recounts it. Counting is one pass over the ledger with a binary search per entry.
- Fixed on the way: with a retained Record draft the Actual's context line dropped its warnings (window unresolved, unreadable roles) because of an `if` precedence; the new check fails on the old line and passes now.
- Checks (synthetic): bar contents, marking and fit at 100/80/48/32 columns; picker rows, counts, totals, `now`, period switching that keeps the chosen time, Enter for Cycle/Month/Year/All/Day with the selected day, missing presets, reload recount, Escape, and through the Shell: overlay, footer, Space kept, Ctrl-R, Enter, no writes. tmux captures of a synthetic 15-month book at 100×30, 80×24, 48×14 and 32×9. `./tools/check`, `./tools/tui --self-check` and the PTY smoke passed locally.
- Timing (synthetic 109.5k entries, native, best of 5, temporary bench removed after use): moving in the open picker and painting 11 ms, choosing a window and painting 12 ms, the Actual alone 11 ms; opening the picker or switching to Cycle/Month/Year 60–63 ms, to Day (10,950 days) 166 ms. Opening and switching exceed the 16 ms key target at that size; the household is far smaller. No household data was accessed; the paired comparison with LOAM was not executed (LOAM has no picker).

## Calendar removed (2026-10-22)

- User decision 2026-10-22: the Calendar (Day / Month / Year) is deleted; the Actual's period windows are where periods are browsed and chosen. The bonsai Home stays as its own stateless screen (`tui/screens/home`): `Enter`/`a` Actual, `r`, `s`, `b`, `d`, `i`, `o`, `q`/`Esc` quit; `g` and the Commands entry are gone.
- Removed with it: the `Calendar` route and screen, `Screen.env.calendar`, `Set_calendar`, the zoom/jump/month-grid code of `Daily_calendar` (now date arithmetic only), the `Calendar_dates` style, and the ambient fallback that let `/` and `j/k` on other screens drive the hidden Calendar browser. The Shell keeps one `focus_day` (the day the session started; Selected Day uses its own day) as the default date of a new Record or plan, as before; Liquidity and Multicurrency Spend default to today. The Selected Day header is the day alone (no "Day view").
- Checks (synthetic): Home entrances and the absent Calendar entrance at six sizes, Home/Actual routes, Selected Day header at four sizes, Liquidity and Multicurrency defaults; `./tools/check`, `./tools/tui --self-check` and the PTY smoke (`tools/ci-tui-pty`, four sizes and the narrow Preview refusal) passed locally; a tmux capture of a synthetic book at 80×24 and 32×9 showed the five entrances. No household data was accessed; the paired comparison with LOAM was not executed (Calendar has no Bakhlo counterpart now).

## Trend chart cell alignment (2026-10-22)

- Reproduced on a synthetic two-series Trend / Locus report in a real tmux PTY:
  colour changes dropped cells, breaking slopes and moving the selected-day
  guide left by different amounts on different rows. `Ui_chart.multi_line_spans`
  now flushes the old span and retains the first glyph of the new span, reusing
  its buffer. The selected marker's vertical projection uses the same 4×
  subpixel height as the braille line, rather than a coarse text-row projection
  that put a marker on a different row in a short plot.
- Before/after captures at 120×36 and 48×14 show continuous lines and a straight
  selected-day guide after the span fix; selection and resize were also exercised
  at 80×24 and 32×9. These are synthetic terminal observations, not physical
  terminal/font or human acceptance. No accounting values, range selection,
  Daily Pace chart path, configuration format or storage behaviour changed.
- The final 48×14 capture also confirms the detached marker is gone. Book and
  both synthetic config files have identical SHA-256 hashes before/after.
  Regression checks cover preserved row width, a last-column selection guide
  after colour transitions, and no detached marker in a three-row plot.
  The focused `trend_locus_screen_checks.exe`, `./tools/check`,
  `./tools/tui --self-check` and `./tools/ci-tui-pty` all passed.
- Household data was not accessed. Latest-data paired comparison, physical
  terminal/IME and human acceptance **not executed**.

## Actual: a Year window and year moves (2026-10-22)

- `f` cycles Today/Cycle/Month/Year/All; `{`/`}` move the current period a year (the window containing the current window's first day, moved by a year), so Month 2026-10 goes to Month 2025-10. A Cycle a year away outside the configured presets is refused with its reason; All refuses. The footer names `[{ }] year`.
- Checks (synthetic): the Year window, year moves back and forth, the refusal outside the presets. `./tools/check`, `./tools/tui --self-check` and the PTY smoke passed on this commit; a household-copy capture at 100×30 kept its bytes unchanged.

## Actual by day, opened from Home (2026-10-22)

- Trial (user decision 2026-10-22): Home `Enter` opens the Actual; the Calendar stays on `g` until the user decides. Calendar `a` opens the Actual on the Cycle window containing the selected day, with that day selected.
- The list is grouped by day: a heading per day (date, weekday, "1 entry"/"N entries", EXPENSE-role total per Measure over the rows shown, so a Locus filter or search keeps count and total consistent), entries indented under it; `+?` marks a role-less effect, an unreadable roles file shows "No day totals: <cause>". A non-date order draws no headings.
- `f` cycles Today/Cycle/Month/All, `[`/`]` move the window; Cycle and Month come from `Period_window` (tui/book), the one period engine the reports also use. Below 30 terminal rows Details closes (opened by `i`): at 80×24 the list shows 16 rows instead of 6.
- Checks (synthetic): grouping, headings, totals with/without roles and under a filter, partial marker, roles notice at 80 columns, windows, focus day, compact layout, Home/`g` routes. `./tools/check` (with the architecture check), `./tools/tui --self-check` (47 PASS) and the PTY smoke passed on this commit; captures of a household copy at 100×30 and 80×24 kept its bytes unchanged. The paired comparison with LOAM was not executed.

## Trend series colours (2026-10-22)

- Each Trend series has its own colour on its braille line and on its legend entry (name and per-day value), so a name and its line match at a glance. The Terminal theme uses the terminal's own ANSI slots (blue, magenta, cyan, red; no yellow, which washes out on a light background, and no red/green pair), the Bakhlo themes keep their tuned indexed colours, and a cell shared by two series takes the later series.
- The marker glyphs (●◆▲■□) keep the chart readable without colour, the right edge is one border (the plot ends a cell earlier, so nothing doubles or overwrites the frame) and the span building is linear. Rows carry styled spans through the one rendering path; no truecolor, no fixed background.
- Checks: the series styles, the legend matching its line, the overlap rule, the cue, the theme colours and the single border at 80 and 110 columns; `./tools/check`, `./tools/tui --self-check` and the PTY smoke passed, and a Trend capture at 100×30 on a household copy in ignored scratch kept the colours.

## Stock–Flow: the opening entry is not a flow, and an unknown Net stays unknown (2026-10-22)

- An opening entry sets balances, so the whole entry is left out of the window's
  flows: its counterpart posting (e.g. opening equity) is no longer counted as a
  decrease, and the tracked increases and decreases cancel again.
- Start and End still carry that entry, so the motion is unknown: the Net cell of
  every row the entry touches, of the Total row and of the "Net change in tracked
  balance" line shows `—`. The note names each excluded entry by its id and says
  that Start and End include it while `+In` and `-Out` do not. The exclusion is
  keyed by (Measure, entry), so an opening of another Measure never removes this
  Measure's flows.
- Checks: a window containing the opening entry with the counterpart tracked (no
  flow on either side, the aggregate cancels, the affected rows and the Total row
  keep an unknown Net, the note names the entry), an opening of another Measure
  (this Measure's flows stay), and an undated observation (the Net cell is `—`
  while `+In` keeps the motion). Each check fails against the previous code.
  `./tools/check` and `./tools/tui --self-check` passed; a Stock–Flow window on a
  household copy in ignored scratch showed the unknown Net and the note, and the
  copy's bytes were unchanged. The latest-data paired comparison was not executed.

## The launcher runs pushed code only (2026-10-22)

- `tools/household` fetches `origin/main`, builds it in an ignored worktree at `.run/src` and installs the built binary at `.run/bakhlo_tui.exe` (copied to a temporary name and renamed); it always runs that copy, so a failed later build cannot take the last good binary away. It prints the build it starts, keeps Dune's errors on stderr without its directory chatter, keeps the last installed binary when offline or the build fails, and refuses without any binary; the backup commit and push are unchanged. The script itself runs from the working tree: only the TUI binary is pinned to `origin/main`.
- The line that names the commit names the installed one only: without the stamp it says the commit is unknown, never the worktree's HEAD. A stale `.run/src` (a leftover directory with a stale `.git` file) is the launcher's own ignored directory: it is cleared, pruned and made again.
- Checks cover the moved origin, offline, the failed build (its fake build removes the target it would have replaced, and the previous copy still runs), the installed copy being the one that runs, the stale worktree recovery, the unknown commit, and the refusal; `check` and `--self-check` passed.

## Stock–Flow debt history from openings (2026-10-22)

- An `openings` entry gives a known start at the opening entry's own day: a
  window starting strictly after it is exact; a window that contains the opening
  entry keeps `—` and shows no flow for it, because the opening posting sets the
  balance; a window ending before it keeps `—` for the start and the end.
- Boundaries are anchored on Core's exact current quantity minus the recorded
  Effects dated on or after the boundary day. An observation is exact only at
  its confirmation, so its window boundaries stay unknown.
- The liabilities section shows start / +In / -Out / end per window: neutral
  names, because the sign decides which side is a repayment.
- Checks cover the opening exactly on the window start, a window containing and
  a window ending before the opening, a cold reload of an opening book and the
  liability row columns; `check`, `--self-check`, the PTY smoke and a read-only
  fresh-copy capture (100×30, 80×24) passed with the household bytes unchanged.

## Suspense never silently stays pending (2026-10-22)

- Attention gains one derived row when Actual entries touch `suspense`: the
  exact net of the recorded suspense postings per Measure that uses them,
  labelled "recorded net" and never a balance (the holding Locus has no history
  support); a Measure whose recorded net is zero is not listed. The row also
  shows the entry count and the oldest entry with its age. No entry, or every
  recorded net zero, hides it; one scan per book version feeds the row, the
  detail and the keys.
- Manage Loci never counts `suspense` in "N without role" and refuses it an
  accounting role: assigning one points at the Actual correction, admitting it
  points at Record's "enable unresolved recording" (Ctrl-U). It is the
  unresolved holding, and the Balances accounting view lists it as an unresolved
  role gap, which qualifies Net Worth as unknown while it holds something.
- Checks cover the non-zero, zero, multi-Measure, no-entry and unsupported
  cases, the count and both refusals; `check`, `--self-check`, the PTY smoke
  and a read-only fresh-copy capture (100×30, 80×24) passed with the household
  bytes unchanged.

## Manage Loci: a role is required on admission and may go to a used Locus (2026-10-22)

User decision (2026-10-22): every new Locus gets an accounting role, and a used Locus
without one may still receive its first role (LOAM refuses used Loci). Roles stay
initial-only: an assigned role is never replaced.

- `tui/screens/loci/loci_screen.ml`: the admit form refuses `(Choose a role)` and refuses
  up front when roles are unreadable or the token already has one, so an admission never
  leaves its Locus without a role. `r` no longer refuses a Locus used by Actual or
  Scheduled evidence. The list title counts Loci without a role.
- `setup_integration_checks.ml` (synthetic): admission without a role is refused and
  admits nothing; on a separate copy whose roles omit a used Locus, the title shows the
  count, `r` opens, an empty choice is refused, Expense is saved once and a second `r`
  is refused; replacement is still refused.
- `./tools/check`, `./tools/tui --self-check` (45 PASS). On a scratch copy of the
  household (100×30, 80×24) the title read `3 without role` (two used Loci and
  `suspense`), `r` saved Expense to the copy's roles file; the household's book and
  roles bytes were unchanged. Physical terminal/IME and human acceptance **not executed**.

## Stock–Flow follow-ups (2026-10-22)

- The debt section refuses an unreadable `accounting-roles.tsv` by name (like Trend
  and I&E); the unknown-start footnote now says the start total is the partial one and
  every known end is still added; All Time gives a zero-origin coordinate an exact 0
  start while a bounded start stays unknown. Checks cover all three; `./tools/check`,
  `--self-check`, the PTY smoke and a 160×45 All Time capture passed.

## Stock–Flow with bounded history (2026-10-22)

- Qualification now uses the same rule as Daily Pace (`pool_at_end_of_day`):
  zero-origin or bounded history, no second engine, no fabricated zero; the window
  defaults to the configured cycle.
- A window before a coordinate's bounded start shows that start as unknown (—) while
  others render; unsupported coordinates are listed with their state; rows show
  start / +In / −Out / end / net and a Liability role keeps its remaining balance.
- Checks cover zero-origin, bounded after/before start, mixed, unsupported,
  liabilities and a cold reload; `./tools/check`, `--self-check` and the PTY smoke
  passed. Read-only 160×45/80×24 captures match LOAM's reconstructed end plus the
  post-cutover difference; intentional: cycle default, per-coordinate rows.

## Trend data-driven series and braille chart (2026-10-22)

- The default series are the three Expense-role Loci with the most recorded entries
  in the shown history (ties: larger movement, then token), derived on every open;
  `a` still edits the session only and nothing is written to config.
- The chart reuses the single braille plotter (moved into `tui/kit`, extended for
  several series): zero-based money axis, per-day values in the shared money format,
  period labels, and interpolation when points outnumber columns; the coverage
  disclaimer moved to `?`.
- Checks cover the busiest-Locus default order, the help overlay, braille output and
  x labels; `./tools/check`, `--self-check` and the PTY smoke passed. A read-only
  latest-data run at 160×45/80×24/48×14 matched LOAM's series and wrote nothing.

## Income & Expense as a cycle summary (2026-10-22)

- Default window is the configured cycle containing today (Month/Year/All and [ ]
  remain); without a preset it keeps the explicit refusal, never an inferred Month.
- The 80×24 screen answers Income, Expense and Result with the previous window of the
  same kind and the exact difference, plus Scheduled vs other; rows are sorted by exact
  amount with a leftover-width bar and never-clipped amounts (at 48 columns the
  comparison becomes `Δ`). `c` compares windows side by side; inactive Measures stay
  one line and unresolved role effects follow the totals.
- Pure checks cover diffs, order, bars and compare widths; scenario checks cover the
  cycle default and `c`. `./tools/check`, `--self-check` and PTY passed; the read-only
  latest-data run wrote nothing and left copies unchanged (LOAM has no cycle default).

## Shared report frame and Observe safety (2026-10-22)

- Observe Preview defaults to `Edit`; `Publish` needs an explicit choice, and Esc from
  Balances returns to Balances after Observe left the reports palette.
- Income & Expense, Transactions Flow and Stock–Flow share one full-width frame: `?` help,
  one clamped scroll model (j/k, PgUp/PgDn, Home/End, g/G) with a `first–last / count`
  row, and Balances' `format_money`. The formulas pane, `max_int/4` End sentinels and
  per-screen handlers are gone; Transactions Flow details only from 100 columns (Enter
  full width below), and I&E lists active Measures and prints real lines (no `\u000a`).
- Checks, `./tools/check`, `--self-check` and PTY passed. Read-only latest-data I&E/TF/
  Stock–Flow at 160×45 and 80×24 stayed readable; totals differ only by the post-cutover
  record missing from the frozen LOAM view; Stock–Flow still refuses without zero-origin
  support; copy bytes unchanged.

## Actual render-local reuse and empty-query search (2026-10-21)

- Actual resolves scope/Loci, filtered sorted rows and clamped selection once per
  render, sharing them with context/list/details. Detail scroll limits are computed
  only for Details navigation. Public unclamped selection and the All-loci fast path
  remain intact. No persistent cache, state field, API, storage or dependency change.
  `Record_browser.matches` keeps day/Locus filters while skipping text construction
  for an empty query. Tests cover both row families, their labels, independent memo
  search, intersected filters and stale selection; existing lifecycle checks remain.
- Before/after native executables compared 1,440 synthetic observations: empty and
  18-entry books (long CJK/huge quantity), 39 keys plus initial state, six geometries
  (120×36, 80×24, 48×14, 32×9, 20×6, 8×3) and three themes. Serialized rows, footer,
  cursor, visible/selected IDs, Locus, notice, command and ANSI digests were identical.
- Paired native measurements on macOS x86_64 / OCaml 5.3.0: median of nine after
  warmup, synthetic All Current / two Loci / empty query / 80×24, same saved probe
  source linked before/after. These are CPU-side key/paint costs, not PTY latency:

  | Synthetic entries | Shell Down + Notty image/cursor, before→after | Empty-query filter only, before→after |
  | ---: | ---: | ---: |
  | 1,000 | 2.152→1.453 ms | 0.434→0.022 ms |
  | 10,000 | 23.974→14.018 ms | 4.814→0.257 ms |
  | 109,500 | 465.517→234.804 ms | 53.078→6.703 ms |

  The 109.5k 16 ms key-response goal is **not met**. Full-list sorting and the
  unchanged global amount-width scan remain; this is not a claim of complete tuning.
  A follow-up process-wide projection cache (`2abf471`, warm keys ≤4.1 ms) was
  reverted: no slowness has been felt on the household, and it added shared mutable
  state and retained an old book. Revisit only when Actual is felt slow.
- `./tools/check`, `./tools/tui --self-check`, the four-size synthetic
  `tools/ci-tui-pty` matrix and `./tools/privacy-scan --all` passed.
- Independent pit review found no blockers. Latest-data paired comparison, human/IME
  acceptance and P7/power-loss testing: **not executed**. No household access.
  Removed the obsolete Records investigation from the design guide and aligned S1
  with the already-approved cutover; no new migration or authority decision.

## Household backup failures are visible (2026-10-21)

- `tools/household` checks staging, index comparison, commit, upstream, pending-log
  and push outcomes. Failures retain Git's diagnostic and stop the backup sequence;
  a successful TUI then exits 1, while a nonzero TUI status takes precedence. Local
  commits remain available for the next run's push, even without a new edit. Whole
  household/config staging remains unchanged; no remote is automatically configured.
- `test/household.t` uses only synthetic local Git repositories, bare remotes and a
  fake TUI: clean/saved success, config retention, refused commit, absent upstream,
  refused push then successful no-edit retry, TUI status priority, staging lock and
  failed pending-log command. Git settings are isolated and no network is used.
  `sh -n tools/household` and `dune runtest test --force` passed via `tools/opam`.
  `./tools/check` and `./tools/tui --self-check` also passed. CI path filters now
  include launcher-only changes.
- Operational household and private backup were not accessed. Actual off-site restore,
  human/IME acceptance and power-loss testing: **not executed**.

## Accounting uses current entry coordinates after publication (2026-10-21)

- Two read-only pit workers inspected storage and Scheduled. Speculative storage
  concerns and dismissal of a refused-save chooser were not accepted as established
  defects or reasons to discard drafts.
- Confirmed separately: Accounting discovered coordinates through `Q.source (B.image
  book)`, whose admitted source intentionally lags incremental mutations. A newly
  used coordinate could be missing until reload, or an old coordinate remain after
  correction. `Daily_overlays` now scans current corrected entries, retaining the
  support-coordinate union, exact Locus/Measure identity and image-keyed cache.
  No storage format, admission or quantity calculation changed.
- Regression: real synthetic append shows the new coordinate as unsupported (not
  zero), and matches cold reload and `Daily_book.Full`; after reopening and correcting
  away its last use, it disappears and again matches cold/Full. The old book's rows
  remain unchanged. The new-coordinate assertion failed before the fix and passed
  after it. `./tools/check`, `./tools/tui --self-check` and the four-size synthetic
  `tools/ci-tui-pty` matrix passed. Both workers reviewed the focused fix with no
  blockers; the parent checked their reasoning against the actual entry/image code.
- Household data was not accessed. Latest-data paired comparison, human/IME
  acceptance and P7/power-loss tests: **not executed**. The underlying admitted-source
  lag documented in `Daily_book.image` is unchanged, not claimed fixed globally.

## accounting-roles.tsv refuses instead of skipping (2026-10-21)

- User decision (2026-10-21): a malformed `accounting-roles.tsv` is refused, not silently
  skipped. Before, a bad row, an unknown role name or an unreadable file meant "no role" for
  that Locus everywhere, and assigning a role in Manage Loci rewrote the file without the
  skipped rows. Now the parser names the line of a malformed row, unknown role, empty Locus
  or repeated Locus; the Shell's roles are a result (never an empty list for a bad file) and
  are read where saves write (`config_file_path`; the separate `read_config` search order is
  removed). Balances Accounting, Income & Expense and Multicurrency Spend show "Accounting
  roles unavailable: …", Manage Loci shows `[?]` and refuses role saves; quick capture only
  loses its role-based Locus suggestions.
- New checks: accepted header/comments/blank/CRLF, four refusals with line numbers, the
  Shell error and the Balances Accounting message (a deliberately wrong expectation made
  the self-check fail). `./tools/check` passed.
- A scratch copy of the household roles file read cleanly under the new rules (42 rows,
  1 header, 0 refusals); the copy was deleted. The household was not written.

## Daily Pace, Actual and shared input readability (2026-10-21)

- `51b62aa`: Daily Pace `rows` (121 lines) split into context, trend and unavailable parts.
  `bbbe30a`: the Actual pane cycle is named once. `70e2b73`: nine copies of the
  case-insensitive key match became `Ui_input.key_ignoring_case`; `Locus_roles` reuses the
  accounting-roles parser in `Daily_overlays` instead of a copy.
- Guard for each: the temporary dump (40-key script, 6 sizes × 3 themes) of Daily Pace,
  Actual, Scheduled and Balances was byte-identical before and after (2.7–3.4 MB each);
  `./tools/check` (45 suites) passed.
- Not changed, for a user decision: the accounting-roles reader silently skips malformed
  lines and unknown role names instead of refusing them.

## One boundary-presets parser for every screen (2026-10-21)

- Five copies read `boundary-presets.tsv` (Daily Pace today, its cycle form, Trend, Income &
  Expense / Trend-Locus, Multicurrency Spend) and disagreed: Daily Pace kept `\r` and spaces
  (a CRLF file made today's pace "malformed" while its Trend read it), and the cycle form
  refused blank lines. `tui/book/boundary_presets.ml` is now the only parser: lines trimmed,
  blank and `#` lines skipped, the same name/date rules; each screen keeps its own refusal
  wording. A new pure check covers CRLF/comments/blank lines, every refusal and the
  half-open windows.
- Guard: a temporary uncommitted dump painted Daily Pace and Actual through a 40-key script at
  6 sizes × 3 themes (3.4 MB and 2.8 MB of ANSI) before and after; byte-identical.
  `./tools/check` (45 suites) passed. Household data not accessed.

## Screen readability and a CI race in the app checks (2026-10-21)

- Scheduled (`35fb94d`): `handle` became a dispatcher; Months and List got named handlers,
  `motion_delta` replaced three copies of the motion-key match. Balances (`1c7408f`): one `move`
  path replaced six hand-written list/detail motions (973 → 925 lines). No behavior change.
- CI for `1c7408f` failed: `app_checks` could not find `scratch/examples/daily-book.sexp`
  right after writing it. The checks ran in `_build/default`, where Dune removes files it did
  not produce while other rules run; the earlier green run was timing luck. The runner now
  works in a fresh resolved temporary directory (removed after success, kept on failure).
  `./tools/check` passed locally after deleting `_build/default/scratch`; household data not
  accessed.

## Notty adopted; Bonsai_term and OxCaml removed (2026-10-21)

- User decision (2026-10-21) after the trial below and their own run on a household copy,
  reported as working (IME and paste were not reported separately; missing Daily Pace details
  came from the copy lacking `config/`): the TUI uses Notty; Bonsai is explored outside Bakhlo.
- `notty-community 0.2.4` and `uutf` are direct dependencies (ADR 0001); the lock gains exactly
  `cppo`, `notty-community`, `ocamlbuild`, `topkg`, `uutf` and changes nothing else (56 entries).
- The TUI is now part of the main Dune workspace (`tui/dune-project` keeps
  `implicit_transitive_deps false`, `tui/dune` the compiler policy). Building it in the dev
  profile exposed 19 warnings the release-profile Bonsai build had hidden (unused parameters,
  a never-built constructor, an unused `rec`, an unused open); all fixed by removing the dead
  code. Removed: the Bonsai adapter and entry, its checks and parity check,
  `tools/build-bonsai-tui`, `tools/build-notty-tui`, `tui.yml` and `tui/.ocamlformat`;
  `tools/tui` builds `_build/default/tui/app/bakhlo_tui.exe`.
- `./tools/check` (31 s) now runs Core and all 44 TUI suites; `./tools/tui --self-check`,
  `./tools/format --check` and `tools/ci-tui-pty` on `bakhlo_tui.exe` passed. `core.yml` adds the
  PTY smoke. The ignored local `scratch/tui_comparison_review/bonsai-env` was not deleted.

## Notty terminal adapter trial beside Bonsai (2026-10-21)

- User decision (2026-10-21): try Notty in place of Bonsai_term, since the TUI uses none of
  Bonsai's composition or incrementality. `tui/app/notty_render.ml` paints the Shell rows with
  the Bonsai adapter's colour and glyph rules; `notty_terminal.ml` drives the Shell with
  `Notty_unix.Term`; both entry points share `daily_cli.ml`. `effect` identifiers in 12 TUI
  files were renamed (`posting`, `original`, `leg`, `make_effect`) because OCaml 5.3 reserves
  the word. Trial dependency: `notty-community 0.2.4` (+ `uutf`, build-only `cppo`) installed
  locally with `./tools/opam install notty-community.0.2.4`; `bakhlo.opam.locked` unchanged.
- Under OxCaml both adapters build; a new check renders 1008 Shell states (3 themes × 8 sizes ×
  42 states) with each and requires byte-identical ANSI, and equal cell widths for control,
  malformed, CJK, half-width and emoji samples: PASS.
- With the ordinary compiler, `tools/build-notty-tui --test` runs all 44 suites (shared Shell,
  screens, scenarios and the ported terminal checks) with the Notty width function: PASS.
  `tools/ci-tui-pty` on `notty_daily.exe`: all four sizes and the Record Preview refusal PASS.
- Same Mac, uncached: build 27 s (Bonsai) vs 9 s (Notty); build + self-check 29 s vs 16 s;
  executable 58.5 MB vs 8.1 MB; idle CPU over 10 s 0.22 s vs 0.00 s; paint + ANSI per frame
  0.92 ms vs 0.83 ms. External keypress latency could not be compared reliably (Bonsai keeps
  emitting output; the probe's polling dominates). TUI CI today takes ~3–3.5 min.
- Not done: macOS IME, paste and terminal restore by the user; CI for the Notty build; removal
  of Bonsai. Household data not accessed.


## Unused TUI values removed (2026-10-21)

- 21 interface values had no user outside their own module; they are no longer exported.
  A one-off uncached build with `-w +32` (the TUI uses the release profile, where unused
  values are silent) then found 11 definitions used nowhere, now deleted; a second such build
  reports none. The permanent compiler policy is unchanged.
- `./tools/tui --self-check` (44 suites, no warnings), `./tools/check` and
  `./tools/format --check` passed. Household data not accessed.

## Record draft builder: unused paths removed (2026-10-21)

- `tui/book/daily_draft.ml` 575 → 321 lines. Removed the unused two-posting form path
  (`Single`, `single_form`, `prepare_postings`, `prepare_pay`, `Pay_*`), the never-read
  `field`/`raw_cause` of `transaction_error`, and `edit_preparation` (now
  `edit_refusal : string option`). Date, posting and balance checks that were written out two
  or three times are single functions; their order and every user-visible message are
  unchanged.
- `./tools/tui --self-check` (44 suites, no warnings), `./tools/format --check` and the local
  PTY smoke passed. Household data not accessed.

## Record editor readability (2026-10-21)

- `tui/shell/record_session.ml` (1491 → 1430 lines after formatting): shared `blank`
  constructor, `open_plan_draft` for Scheduled edit/payment, `settle`/`with_rows` for the
  repeated caret/candidate/notice reset, `split_sign` for the three sign parsers, helpers for
  the original-amount editor, and comments on the focus order and review actions. Edits and
  payments no longer build an unused quick-capture history. No behavior change intended.
- `./tools/tui --self-check` (44 suites incl. Record, quick capture, original amount and
  Ctrl-U remainder) and the local PTY smoke `tools/ci-tui-pty` passed. Not compared with LOAM
  on real data; household data not accessed.

## TUI formatting and compiler policy (2026-10-21)

- `4e7e023` formats `tui/` (163 of 179 files were unformatted) and the remaining Core files
  with ocamlformat 0.29.0; `tui/.ocamlformat` targets OxCaml's 5.2 syntax, and
  `./tools/format --check` now covers `tui/`. Nine interfaces had doc comments squeezed
  between two declarations; a blank line now fixes their attachment. Formatting only.
- The TUI project did not inherit the root `-warn-error +8+9+11` (a nested
  `dune-project`), so three warnings had gone unnoticed: two non-exhaustive matches in
  `record_session_checks.ml` (missing `Enable_unresolved`, now a failure case) and a
  useless `with` in `shell_view.ml`. `tools/build-bonsai-tui` now writes the same policy
  into the TUI project; a temporary partial match fails the build as
  `Error (warning 8 ...)`.
- `./tools/check`, `./tools/tui --self-check` (44 suites, no warnings) and
  `./tools/format --check` passed. Household data not accessed.


## Research and pre-cutover documents moved to Git history (2026-10-21)

- Removed `docs/archive/`, the storage, canonical-data and TUI geometry/layout research,
  the capability ledger, LOAM core inventory, references and ADR 0003, plus the 108
  VERIFICATION sections dated before 2026-10-20 (520 KB → 137 KB). All remain at
  `90a5867`; every link to them now points at that commit on GitHub.
- Rewrote README (daily use via `./tools/household`), a short current ARCHITECTURE, and
  trimmed DEVELOPMENT/CONTRIBUTING of the old CLI, Lean, VM and SQLite text.
- A link check over all Markdown found no broken relative links or anchors (four
  pre-existing ones in `CUTOVER_CHECKLIST.ja.md`, stale since `bddbd9b`, were repointed).
  `./tools/privacy-scan --all` and `./tools/check` passed. Household data not accessed.

## Off-path code removed; PTY smoke moved to Expect (2026-10-21)

- Removed the old CLI (`cli/`, `bin/`, `presentation/`, `text/`, `sexp/book.ml`),
  `application/{current_quantity_answer,movement_check}`, their tests and fixtures,
  `migrate/bin` + `tools/import-loam`, `experiments/`, `formal/`,
  `tools/check-root-cut-laws`, `tasks/issue42` and two experiment workflows; all
  remain in Git at `dfd03d1`. `bakhlo_sexp` no longer links `unix`.
- Kept coverage rewired: the LOAM-read test now asks `Current_quantity_query`
  directly (wallet exact, pantry present, stale unknown — the same three outcomes the
  CLI exit codes 0/4/3 expressed); the oracle's known-gap test inspects the image's
  correction frontier instead of the explanation text.
- `tools/ci_tui_pty.py` → `tools/ci-tui-pty` (Expect), same flows and assertions.
  Local macOS run: all four dimensions and the Record Preview refusal PASS (34 s);
  a deliberately wrong expected balance fails. Linux CI result: see the run for the
  matching SHA.
- `./tools/check` and `./tools/tui --self-check` passed. Household data not accessed.

## Trend / Locus comparison report (2026-10-21)

- Branch: `omp/trend-locus`, based on `origin/main` (6 commits behind, not rebased). Read-only LOAM behavioral references only: `Loam/Review/LocusTrendCompareReview.lean` (window/scope/average semantics) and `Loam/Tui/LocusTrendComparePane.lean` (picker, overlays, `withSnapshot` anchor). The sibling Lean repository was not built, modified or copied.
- New pure projection `tui/screens/reports/trend_locus_report.ml/.mli`: exact signed Effect-quanta sums per `(locus, measure)` from the current `B.entries`, over explicit adjacent cycle windows / calendar months / single days. One explicit `boundary-presets.tsv` preset must contain the observation day; its first boundary is the only history start and every scope is clipped to `[historyStart, observed_at+1)`. Cycle/Month values are Euclidean floor `total/observed_days` (`Z.ediv`, so `-1/3 = -1`, not `0`); Day is the exact daily total. `complete` means the point spans its full natural window (the observation Day stays partial) and is never an evidence or household-coverage claim.
- New owner `trend_locus_screen.ml/.mli` plus owner-local `trend_locus_chart.ml/.mli` (`Screen.Workspace` layout). The observation day is the Shell focus day captured by `enter ~focus_day`; the owner reads no clock and writes no file. Selection is an immutable `selected_period`; the effective index is derived from the current projection, so `view`/`result` have no side effects and never keep a stale chart. A grain or scope change relocates the remembered period to the newly effective point (LOAM `withSnapshot` anchor rule: the next change anchors on the new point's start), which is why Day→Month→Day lands on the month's first day rather than the original day. Non-Day grains always project All history while remembering the Day scope.
- Series picker (`a`): 1–5 target = occupied or next-empty slot only, cyclic candidate cursor, duplicate refusal keeps the picker open, `x` removes keeping at least one series, `q`/`Q`/`Esc` close only. The candidate catalog inherits the plotted common Measure, so an explicit jpy selection stays jpy after the Shell Measure changes. Session annotations (`o`/`v`/`O`) capture the full `YYYY-MM` and month length when the editor opens, accept only digits separated by space/comma/dot, reject day 0, nonexistent days and 96-digit tokens with the entered text retained, and are never persisted; the same month in two different years stays distinct.
- Chart: five distinct marker glyphs (`●◆▲■□`, `◎` on collision) with no new palette entry, adjacent exact points connected by an integer Bresenham path, bounded rational Z scaling with no float or machine-sized conversion. When an exact axis label or series value cannot fit, the surface shows `widen for exact axis values` / `(widen)` instead of a truncated number. Zero is painted as an exact empty recorded sum, never as a balance or support assertion.
- Shared edits were additive only: one `Trend_locus` route constructor (`tui/protocol/screen.ml/.mli`, mirrored in `tui/shell/ui_workspace.ml/.mli`), one Commands action plus its `Reports and analysis` item (`ui_commands.ml/.mli`), one dispatch case (`shell_dispatch.ml`), one Shell title case (`shell_view.ml`), one registry field/`create`/`Owner` (`screen_registry.ml`), and one additive export of the existing boundary parser (`income_expense_report.mli`). No Core, kit, API, protocol `env` or Scheduled change.
- `tui/screens/reports/test/dune`: the existing `reports_checks` stanza was pinned to `(modules reports_checks stock_flow_checks)` and three explicit stanzas added. Reason: `tools/arch` requires every `*_checks` module to be run by a named main, and each new check needs a different library set (`bakhlo_tui_protocol` only for the owner, `bakhlo.domain`/`bakhlo.sexp` only for the projection, `bakhlo_screen_reports`+`zarith` only for the chart); auto-inclusion would have linked them into one executable with the union of libraries and no main reference. No `Base` is used in any new test.
- Passed: `rtk test ./tools/build-bonsai-tui --test screens/reports` (exit 0; four suites), `rtk test ./tools/tui --self-check` (exit 0), `rtk test ./tools/check` (exit 0, includes `./tools/privacy-scan`), `rtk git diff --check` (exit 0). No private-token comparison was executed (no private household copy in this worktree).
- Native synthetic proof: a disposable tmux driver on its own server exercised the Commands route, Cycle/Month/Day values (`137` / `-138` floor averages; `-120` refund day), the 31-day viewport and Day scopes, the 5-series picker with duplicate refusal, the annotation editor (invalid day 0, `21,21.1`, guides, clear), four geometries (120×36 / 80×24 / 48×14 / 32×9), a scaled-EUR book (`5.82` / `-5.83` / `123.45`), a 601-digit book (widen cue, no partial digits), a renamed `boundary-presets.tsv` (explicit unavailable, then recovery), `q` to Home and a cold reopen with no retained annotations. Synthetic book/config SHA-256 unchanged before and after every read-only flow. Captures stayed in ignored scratch and the throwaway driver was removed after verification.
- **Not executed:** paired LOAM binary or latest-data comparison, real household data, human/macOS IME acceptance, P7/power-loss qualification, CI and push. Pointer scrub is deliberately not implemented: `Ui_input.input` carries `` `Mouse of unit `` with no coordinates, so porting LOAM's click scrub would require a shared kit change; keyboard scrubbing substitutes. Synthetic success is not a claim of whole-screen or binary parity.

## Scheduled replenishment input and explicit dates (2026-10-21)

- Branch/base: `omp/scheduled-replenish`, implementation `aa87144`, based on `710129f`. The earlier stop recorded in `1044248` was cleared by coordinator approval for **only** the generation constructor call in `tui/shell/shell_record_actions.ml`. Other shared Shell/API/Core/kit and other worktrees are unchanged.
- `e` now opens **Next occurrence / Next 3 occurrences / Next 6 occurrences / Custom date** with the monitored cadence locked. Presets use the source's nominal month/day and an exclusive boundary at the first of the month after the last slot; a horizon at/before the observation date or beyond year 9999 refuses, rather than re-anchoring or shortening it.
- `Scheduled_generation_session.create ?observed_at` requires a real canonical observation date for monitored replenishment, without a missing-date fallback or editor clock read. Shell has no retained today field; the authorized constructor call captures `F.today ()` once for monitored `e`, using the same date source as `Screen.env`. Plain `g` passes neither cadence nor observation date and keeps its previous form, cadence choices, date generation/clamping and Preview behavior.
- Custom input accepts only a real ISO exclusive limit strictly after both source and observation dates. Dated candidates are included only when `observed_at <= date < limit`. Missing nominal days (e.g. 31 November or non-leap 29 February) require a blank, explicit date input; no automatic clamp. A human resolution may be any real date in that interval, not necessarily in the nominal month or after the source. All missing slots must resolve before Preview; source Measure and signed arbitrary-precision changes remain exact.
- Read-only behavioral references: LOAM `Tui/ScheduledGeneration.lean` (horizon/custom flow), `Tui/ScheduledGenerationSession.lean` (1/3/6 suggestions and missing-date collection), `Application/ScheduledGeneration.lean` (source anchoring, observation/limit bounds, missing nominal days). No sibling build/modification/source copy.
- Regression before implementation: `rtk test ./tools/build-bonsai-tui --test app` exited **1** at `cadence-requires-observed-date` against the old constructor. The final suite passes that regression plus exact 1/3/6 and 1/2/3/6/12-month dates, old-source past exclusion/today inclusion, canonical-date and exclusive boundaries, calendar overflow, explicit month-end/leap resolution, retained custom limit/resolutions after Preview Esc, 600-digit quantities, blocked/end/tiny refusal, stale reload/base refusal, and atomic cold commit.
- Passed after implementation: `rtk test ./tools/check` (exit 0), `rtk test ./tools/tui --self-check` (exit 0), `rtk git diff --check` (exit 0). Existing generation wording checks were replaced with input/Preview/publication outcome checks; plain `g` still publishes its same expected dates. Integration compiler/test-fixture errors were corrected without weakening the save gates.
- Native synthetic proof: `tclsh scratch/replenish-smoke.tcl` exited 0. Horizon, custom input, Preview and missing-date input were each resized through **120×36 / 80×24 / 48×14 / 32×9**, with active input and short Esc/return hints visible. Exercised Next 3/6 dates, exclusive custom limit, initial Cancel with unchanged SHA-256, tiny Publish refusal, explicit 31-November → 30-November resolution, reviewed Publish and cold reopen with exact **12.34 EUR** effects. Fresh synthetic books/config only; the worker's private tmux server was closed. Captures remain ignored; the throwaway driver was removed after verification.
- Independent review checked date arithmetic/state transitions, metadata, captured revision and unchanged publication gates. It led to explicit expired-horizon refusal and Horizon `q`/`Q` cancellation. Parent integration also separated custom-limit and resolution buffers so Preview-back cannot erase a typed limit.
- Intentional Bakhlo safety differences: Preview starts on **Cancel**, not LOAM's Publish; Preview Esc returns to the retained horizon/input/resolutions instead of discarding the whole generation. Resolution Esc cancels the whole generation; custom Esc returns to the custom horizon choice. Input choices/date rules are source-guided and synthetic-verified, not a claim of whole-screen/binary parity.
- **Not executed:** paired LOAM binary/latest-data comparison (coordinator-owned), physical terminal/IME/human acceptance, P7/power-loss qualification, CI and push. `./tools/privacy-scan` exited 0 but private-token comparison was **not executed** (no private copy here). No `./tools/compare`, `./ui`, household/config or `../loam-data` access; no new dependencies, Python, main or other-worktree edits.

## Scheduled Months and List local parity (2026-10-21)

- Scope: `omp/scheduled-months-list`, implementation `7ae43a8`, based on `a6f57ce`; Scheduled-owned rendering/input and its scenario tests only. No shared Shell/API/Core, Loci screen or storage changes.
- Behavioral reference: read-only LOAM `Loam/Tui/ScheduledWorkspace.lean` (initial/order/filter/navigation, List panels and Months cards) and `ScheduledWorkspaceSession.lean` key mapping. The sibling Lean repository was not built, modified or copied. No household/config inputs or `./tools/compare` were accessed.
- List: earliest date then ID, local Loci filter, captured Calendar focus-day/all-open scope, Date/Shape/right-aligned Amount, responsive Loci/occurrence panels and inline details. `h/l` select fixed panes; pages move eight rows; Enter completes, `r` replaces, `n` creates. Loci focus refuses occurrence edit/complete/cancel rather than acting on a background row. Optional `i`/Tab/`w` full detail preserves selection/filter/query and returns to its origin pane.
- Months: six cards retain the current-month floor, year bounds and ID-following window; month title and explicit count occupy separate borders, with a centered selected row and a bounded inline detail (at most eight rows). Narrow navigation keeps the List/return keys visible.
- Synthetic regression coverage: same-date ID tie, Loci filtering/restoration, day-scope reset, changed-day re-entry dropping obsolete Loci, no-op Loci navigation retaining the occurrence target, fixed focus/page size, targeted completion/cancel, full-detail origin/scroll/query/re-entry, huge amounts, split plans, view cycle, year/floor limits, cancellation cold reload and four-geometry bounds. Removed obsolete Scheduled layout-wording assertions in `publication_integration_checks.ml`; retained its non-publishing inspect behavior using `i`. The overflow fixture was lengthened for the now-full-width detail.
- Passed commands:
  - `rtk err ./tools/bootstrap` — exit 0; worktree-local locked Core environment. The existing isolated Bonsai compiler was reused through ignored environment links; no dependency was added.
  - `rtk test ./tools/check` — exit 0.
  - `rtk test ./tools/tui --self-check` — exit 0, including the Scheduled List/Months, bulk/generation, publication and safety scenarios.
  - `tclsh scratch/scheduled-smoke.tcl` — exit 0. Disposable synthetic book, own tmux server with no user tmux config, 120×36 → 80×24 → 48×14 → 32×9 → 120×36. Exercised ascending initial row, eight-row page, fixed pane focus/Locus filter, background batch/generate refusal, search-empty explanation, `i`/Esc detail return, `f` scope, Enter completion/Esc, Months shift and List/Months resize round trips. Synthetic book SHA-256 unchanged; only the worker's server closed. Text captures stayed ignored; the throwaway driver was removed after verification.
  - `rtk git diff --check` — exit 0. `./tools/privacy-scan` — exit 0 with private-token comparison explicitly **not executed** (no private household copy under this worktree's scratch).
- During integration the TUI check first exposed an inline styled-row type error, then an overflow fixture that fitted the wider detail and obsolete two-pane wording checks. All were corrected before the passing run; no validation was suppressed.
- Independent review caught a stale day-scope Locus on re-entry, no-op Loci navigation retargeting an occurrence, unguarded background batch/generate and ambiguous search-empty text. Added regression guards; `rtk test ./tools/build-bonsai-tui --test app` reproduced `list-loci-pane-does-not-act-on-a-background-occurrence` before the action fix (exit 1).
- Not executed: LOAM binary paired comparison (synthetic or latest data), real household comparison, human/macOS IME acceptance, P7/power-loss qualification and CI (this branch is not pushed). Privacy token comparison is not executed without a private copy in this worktree. These are not inferred from synthetic success.
- Integration: rebased onto `e600e31` (implementation `2888296`, docs `ac3f83c`; only the
  `tasks/todo.md` heading conflict was resolved). On the main checkout `./tools/check`,
  `./tools/privacy-scan --all` (private tokens compared, no match), `./tools/tui --self-check`
  (39 PASS) and `git diff --check` passed. Pushed `ac3f83c`; matching-SHA
  [Core CI 39473259869](https://github.com/shumoku88-bit/bakhlo/actions/runs/39473259869)
  and [Bonsai TUI CI 39473259938](https://github.com/shumoku88-bit/bakhlo/actions/runs/39473259938)
  both succeeded.
- Remaining intentional/local limits: scaled `Amount` rather than LOAM raw `Quanta`; search and optional full detail are retained additions. All occurrence actions (including batch/generate) require occurrence/detail focus, unlike LOAM's background batch entrance; no-op Loci movement retains the target rather than silently selecting another plan. These safety differences have regression checks. Shared Shell outer geometry and the Series/coverage/monitoring/extension workflows are unchanged by this slice; no whole-screen parity or cutover claim.

## Real-data trial saves, exit compaction and unapproved-Locus correction comparison (2026-10-20)

- Fresh `./tools/compare refresh` (LOAM open, originals not written, no user process terminated). Bakhlo `7f37541` (implementation `334d413`), Bonsai executable SHA-256 `4a9b0f8836772a357bea094fffe016d69b73ffc99524b3ba6c76dec19116515b`; existing LOAM executable `1f408694a95efbc865726e2a8eefff4a4d83cf41b01e00897ee42bdee242c703` (source correspondence not certified). Trial writes ran only on isolated copies in `scratch/`; the selected comparison capture and `../loam-data` stayed untouched.
- **Unapproved-Locus entry comparison (paired tmux at 120×36 and 80×24, plus source inspection):** `approved-loci` in Bakhlo's comparison book is copied verbatim from LOAM's `LocusAdmission` section. For an existing entry whose postings use a Locus not in `LocusAdmission`:
  - `c` (`Correction / Edit`, memo-only or posting edit): **both refuse** at Preview (LOAM: `loam: movement uses a Locus not approved for new publication`, `CorrectionPublisher` also checks `locusAdmission.admitsEffects`; Bakhlo: `A Locus is not admitted by the current book.`, `locus-unapproved`).
  - `r` / `x` (`Reversal`): **both refuse** at Publish (LOAM: `loam: reversal uses a Locus not approved for new publication`; Bakhlo: `Publication refused (locus-unapproved). Draft retained.`).
  - `d` (`Date correction`): **LOAM succeeds** (`ActualValidityPublisher` revises only occurrence-date evidence on the retained Event without checking `locusAdmission`); **Bakhlo refuses** (`Publication refused (locus-unapproved). Draft retained.`, because `Date_correction_session` publishes via `Daily_book.put_entry ~replace:true`, which checks `approve_effects` on all postings).
  - `m` (`Merchant classification`): **LOAM succeeds** (`EventMerchantPublisher` attaches disposition evidence to the retained Event without checking `locusAdmission`); **Bakhlo refuses** (`Publication refused (classify-merchant). Draft retained.`, because `Daily_book.classify_merchant` delegates to `put_entry ~replace:true`).
- **Trial saves and 200-record exit compaction on a private real-data copy:**
  - 5 interactive TUI saves in tmux at 120×36 (Correction `c`, Date correction `d`, Merchant classification `m`, Reversal `x`, New Record `r` on approved-Locus entries) appended 5 `(record ...)` lines after the unchanged snapshot prefix; exiting the TUI at 5 records (<200) left the 5 records uncompacted and wrote no `.prev`.
  - Appended 195 more operations via `Daily_file.append` (reaching 200 records across `Put_entry` new/replace, `Put_plan` new/replace, `Cancel_plan`, `Observe`, `Add_locus`, `Set_locus_label`, `Classify_merchant`): 195 saves took 1,150.2 ms total (5.90 ms/save including `fsync`; `Daily_book.Full` took 1,718.8 ms). At 200 records, in-memory `session.book`, cold-loaded `Daily_file.load` (`records = 200`) and `Daily_book.Full` had byte-identical serialization and identical answers/support premises across every approved Locus × Measure coordinate.
  - Opened the 200-record real-data copy in the Bonsai TUI (tested at 120×36 and 80×24) and exited with `q`: `compact_on_exit` (`Daily_file.compact_if_due`) preserved the exact 200-record file as `book.sexp.prev` (byte-identical), rewrote `book.sexp` as a single snapshot with `records = 0`, left no `.compact-*` temporaries, and cold-loaded `book.sexp`, cold-loaded `book.sexp.prev` and `Daily_book.Full` were byte- and answer-identical.
- `../loam-data` (`household.loam` and `config/`) verified byte-identical before/after; AI tmux server stopped; user processes left untouched; private trial directories deleted; `./tools/compare clean-copies` passed. Not human/IME acceptance, P7 or cutover.

## Latest-data check of the 2026-10-20 storage work (2026-10-20)

- Fresh `./tools/compare refresh` (LOAM open, originals not written, no user process terminated). Bakhlo `c773396` (implementation `334d413`), Bonsai executable SHA-256 `4a9b0f8836772a357bea094fffe016d69b73ffc99524b3ba6c76dec19116515b`; existing LOAM executable `1f408694a95efbc865726e2a8eefff4a4d83cf41b01e00897ee42bdee242c703` (source correspondence not certified).
- **Core, real copy, in memory only:** today's code and the pre-today code (`3bda3ca`, built in a scratch worktree) give a byte-identical fingerprint (canonical serialization, every approved Locus × Measure answer with its support kind, plan counts). For every entry, the in-place path agreed with `Daily_book.Full` for a no-op correction, a memo correction (also cold-equivalent) and a refund; re-observing every observed coordinate at its value and value+1 agreed with `Full` and was cold-equivalent; 20 applicable corrections round-tripped through `Book_log` records.
- **Paired UI (tmux, read-only), 120×36 and 80×24:** Balances/Current rows (account, amount, currency, state) identical; Daily Pace Today/Selected/change lines, every visible History row and the detail values (pace, pool, available, remaining days, cycle end) identical. Graph tick values and date axis identical; tick row placement (one row apart) and Braille curve shape differ — the known Grid/Braille gap, rendering code untouched today.
- Finding (not a regression; same before today): entries whose Loci are no longer approved cannot be corrected, even memo-only (`locus-unapproved`, whole-book reference agrees). LOAM's behavior for this case is not yet compared.
- Comparison copies (34 files) and LOAM originals (36 files) byte-identical before/after. Only the AI's tmux server was stopped; a user's own `./ui` session on the previous capture was left running. `./tools/compare clean-copies` run; worktree and private captures deleted. No trial saves were made (not requested). Not human/IME acceptance, P7 or cutover.

## In-place refunds, exchanges and observations (2026-10-20)

- `Daily_book`: admission's entry stage split into `entry_event` and `actual_source`; local admission runs the real `Actual_source.create` over the changed entry plus its Reversal partners (every Actual check concerns one entry or one Reversal pair), with the only book-wide rule (a target is reversed once) checked against the new `reversed_by` index after event construction. All new entries (plain, refund, exchange, original amount, merchant) are now in place; corrections are in place unless they change the Reversal link or touch an opening witness/presence evidence.
- Observation: `Reflected_root_cut.reflecting_all` (membership function, no O(N) map), `Projection.restrict`, `Current_quantity_groups.reobserve_in_place` (older groups restricted, not rebuilt, so in-place deltas survive) and `Current_quantity_query.reobserve_in_place` (rechecks zero-origin/opening/presence separations). The previous implementation is kept as `Daily_book.Full.observe_quantities`.
- Oracle: compares observation with `Full`; generator adds valid and malformed exchanges and corrections that change or drop a Reversal link. Found while testing: a refund of an already-refunded entry with a repeated posting key reported `entry-admission` instead of the whole-book `invalid-entry` (fixed by checking the endpoint after event construction); the oracle's diff helper crashed on a first-line difference (fixed).
- Mutation check: accepting a second refund, ignoring a correction's refund partner, a refund ignoring its target, in-place correction of a changed link, a stale `reversed_by`, rebuilding older observation groups from their cuts, skipping the zero-origin or presence separation, reversed reflected-root order and not reflecting earlier entries each fail the oracle.
- Synthetic probe at 109,500 entries: refund 0.008 ms, exchange 0.006 ms, observation 5.7 ms (≈0.8 s or more before). [Stage 9](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/LONG_TERM_STORAGE_STUDY.ja.md).
- Passed: `./tools/check` (exit 0), `./tools/tui --self-check` (35 PASS, exit 0), `git diff --check`. Synthetic only; latest-data paired comparison not executed.
- Matching implementation `334d413`: [Core 39353235218](https://github.com/shumoku88-bit/bakhlo/actions/runs/39353235218) and [Bonsai TUI 39353235222](https://github.com/shumoku88-bit/bakhlo/actions/runs/39353235222) completed/success (synthetic CI).

## Session revision instead of whole-file bytes (2026-10-20)

- `Daily_file.t` drops `bytes`; it keeps `revision` (size + digest of the final 4 KiB), `size`, `tail` and `torn_bytes`. An append computes the next revision from the appended line only; `Uncertain` carries the `expected` revision and `confirms` compares it after reload. Helpers: `revision_of_bytes`, `read_revision`, `revision_after`. Restore/copy/compaction readbacks compare revisions.
- TUI: `session.bytes`/`env.bytes`/`~base_bytes` renamed to `revision`/`base_revision` (all were opaque bases); uncertain evidence is `Expected_revision`. Scenarios: file-content assertions go through `F.read_revision`/`F.revision_of_bytes`; every place where one variable served as both file content and an editor base was split (audited all `=`/`<>` comparisons involving revisions so none passes trivially).
- Synthetic probe: save ≈0.6 ms at 1,000 / 36,500 / 109,500 entries (36.5 ms before at 109,500). [Stage 8](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/LONG_TERM_STORAGE_STUDY.ja.md).
- Limit: a revision identifies successive saves, not every byte; writes stay guarded by the inode/size/mtime/tail check.
- Passed: `./tools/check` (exit 0), `./tools/tui --self-check` (35 PASS, exit 0), `git diff --check`. Synthetic only.
- Matching implementation `7df640e`: [Core 39351648933](https://github.com/shumoku88-bit/bakhlo/actions/runs/39351648933) and [Bonsai TUI 39351648955](https://github.com/shumoku88-bit/bakhlo/actions/runs/39351648955) completed/success (synthetic CI).

## Append-only saves (2026-10-20)

- `Daily_file` rewritten around `Book_log`: `append` (apply ops in Core → unchanged check of inode/size/mtime/tail under the writer lock → write one record line, fsync, tail readback; records start on their own line even when the file lacks a final newline), `Uncertain` carries the sent line and `confirms` checks it after reload, `discard_torn_tail` (explicit, locked, only an unterminated last line), `compact` (temp snapshot → hard-link old file to `.prev` → atomic rename; spare link removed when rename(2) is a no-op on same-file links), `compact_if_due` (≥200 records) run after the TUI exits. Old attempt/pending/before files and `confirm_current` removed. User decisions recorded in AGENTS.md.
- TUI: every publication (record/correction/reversal/merchant/plans/plan batch/cancel/locus/label/observation) sends `Book_log` operations; uncertain evidence is `Expected_file` (base + appended bytes); recovery notice = torn tail. CLI: `--inspect-recovery` reports torn tail, `--discard-torn-tail` added, `--confirm-current-attempt` removed. Found and fixed while testing: config saves checked the household file as a bare snapshot and would refuse any book with records.
- Tests: `test/daily_file_tests.ml` (append/cold load, refusal and foreign change write nothing, faults at both checkpoints are uncertain and confirmable, torn tail stops writes and explicit discard restores, compaction faults at all three steps keep the book and leave no temporaries on retry, SIGKILL at both checkpoints, missing final newline). `tui/scenarios/recovery_checks.ml` rewritten for the append protocol (torn tail freeze across cold open/Ctrl-N/reload/direct write, 2 faults + 2 SIGKILL, writer lock, real write failure, foreign rewrite never confirms, missing file, healthy save leaves no artifacts).
- Synthetic probe: save 4.73 s → 36.5 ms at 109,500 entries, 0.66 ms at 1,000 ([stage 7](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/LONG_TERM_STORAGE_STUDY.ja.md)).
- Passed: `./tools/check` (exit 0), `./tools/tui --self-check` (35 PASS, exit 0), `git diff --check`. Synthetic only; latest-data paired comparison not executed; not P7/power-loss qualification.
- Matching implementation `9a7e64f`: [Core 39350837090](https://github.com/shumoku88-bit/bakhlo/actions/runs/39350837090) and [Bonsai TUI 39350836734](https://github.com/shumoku88-bit/bakhlo/actions/runs/39350836734) completed/success (synthetic CI).

## Book log format and replay (2026-10-20)

- New pure `Bakhlo_sexp.Book_log`: a book file is the ordinary single-file book (snapshot) followed by appended `(record SEQ DIGEST OP...)` lines; a file without records is an ordinary book. Operations are exactly what the application publishes (`Put_entry`, `Put_plan`, `Cancel_plan`, `Observe`, `Add_locus`, `Set_locus_label`, `Classify_merchant`), with all inputs (IDs, dates) included; a record applies its operations all-or-nothing through the ordinary `Daily_book` functions. Entry/plan syntax reuses the book's v3 codec (`Daily_book.entry_to_sexp` etc., extracted without changing book bytes) and `render_line` (same quoting, one line).
- Load: admit the snapshot, replay records in sequence. Only an unterminated final line is "torn" (reported with `valid_length`, not applied); a digest mismatch (digest covers the re-rendered decoded operations), garbled line, wrong/missing/repeated sequence, terminated bad final line or refused replay refuses the whole file.
- `test/book_log_tests.ml`: 150 seeded runs load snapshot+records to the in-memory book at every step, across random compactions and two-operation records (>1000 records); every cut inside the final line of 40 runs is reported torn with the previous book; damage cases refuse; one record carries every operation kind (quotes, newline, tab, backslash, Unicode, 30-digit amount, keyed posting, merchant party). The oracle now drives `Book_log.op` (adds locus-label edits).
- Mutation check: ignoring the digest, ignoring the sequence (a missing record then loaded silently) or applying an unterminated final line each fail the tests.
- Not yet connected to the store or TUI; publication still rewrites the whole file. Passed: `./tools/check` (exit 0), `./tools/tui --self-check` (35 PASS, exit 0), `git diff --check`. Synthetic only.
- Matching implementation `adc643d`: [Core 39349191425](https://github.com/shumoku88-bit/bakhlo/actions/runs/39349191425) and [Bonsai TUI 39349191404](https://github.com/shumoku88-bit/bakhlo/actions/runs/39349191404) completed/success (synthetic CI).

## In-place corrections, plan and vocabulary edits (2026-10-20)

- `Daily_book`: admission split into stages (vocabulary, entries/Actual, plans, support). Plan create/replace/cancel check only the plan stage and reuse the balance image; locus add/label check only vocabulary. Corrections outside Reversal/Exchange/opening-witness/presence relations are admitted locally (same first refusal as whole admission) and update balances via the new `Current_quantity_query.with_replaced_effects` (per-group: unchanged when the cut reflects the root, else new minus old; `Reflected_root_cut.is_reflected` is indexed). Everything else falls back to whole admission. New plain entries now check the plan before local admission, matching whole-admission refusal order.
- `Daily_book.Full` keeps the whole-book variants as the reference. The oracle compares every operation with both its cold-loaded twin and `Full` (two fixtures, one with presence evidence; 400 sequences × 30 ops; generator adds repeated posting keys, plan-attached corrections, nonpositive/unknown original amounts, merchant parties).
- Mutation check: skipping the balance update, ignoring reflection, dropping the reversal-target guard, skipping the date check, skipping local checks for new entries and skipping the plan stage each fail the oracle.
- Synthetic probe at 109,500 entries: correction 796 ms → 4.3 ms; plan add and locus add ≈1 µs. [Stage 6](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/LONG_TERM_STORAGE_STUDY.ja.md).
- Passed: `./tools/check` (exit 0), `./tools/tui --self-check` (35 PASS, exit 0), `git diff --check`. Synthetic only; latest-data paired comparison not executed (no displayed-answer change intended). The TUI reads no evidence view that in-place updates leave stale; the CLI explanation loads fresh.
- Matching implementation `5afbbc1`: [Core 39347902744](https://github.com/shumoku88-bit/bakhlo/actions/runs/39347902744) and [Bonsai TUI 39347902737](https://github.com/shumoku88-bit/bakhlo/actions/runs/39347902737) completed/success (synthetic CI).

## Records and annual files removed (2026-10-20)

- User decision (Bakhlo not in daily use; destructive changes allowed): removed Records v1 (`records_book`, `durable_append`, `crc32`), calendar-year annual files (`annual_book`, `annual_scope`, `year_read`, `annual_backup`, `Daily_book.Annual_internal`), their store paths (`Daily_file` is now single-file only), TUI annual rollover/notice/history gates and Records publication branches, CLI `--annual-*` options, their tests, the year-partition study tests and the stale storage research tools. Ordinary single-file load/publish/recovery code is unchanged apart from removing those branches.
- `tools/startup-probe` now writes its fixture as ordinary S-expression text; fixtures are byte-identical to the previous run (285,736 / 10,473,607 bytes, same balances).
- Passed: `./tools/check` (exit 0, `arch_check: ok`), `./tools/tui --self-check` (35 PASS suites, exit 0; the only suite no longer present is the annual rollover suite), `git diff --check`. Synthetic only; latest-data paired comparison not executed (no displayed-answer change for single-file books).
- Matching implementation `ea71b08`: [Core 39284457912](https://github.com/shumoku88-bit/bakhlo/actions/runs/39284457912) and [Bonsai TUI 39284457870](https://github.com/shumoku88-bit/bakhlo/actions/runs/39284457870) completed/success (synthetic CI).

## Daily_book cold-equivalence oracle (2026-10-20)

- `test/daily_book_oracle_tests.ml`: 300 seeded sequences × 30 random mutations (record, plan payment, replace, reversal, observe, put/cancel plan, add locus, merchant classification; with invalid dates, zero/unbalanced/unknown-Measure postings and duplicate IDs). Each mutation must give the same refusal reason, or the same observable book (serialization, every balance answer with its premise kind, Daily Pace with deductions, open plans), on the in-memory book and on its cold-loaded twin; the result must also be cold-equivalent. Every family is admitted ≥ 20 times. Runs in ~3 s.
- Mutation check: reverting the observation fix below makes it fail (seed 2, step 8).
- Known gap pinned by its own test: after an incremental record, the evidence explanation (`Current_quantity_explanation`, CLI) omits the new entry until the next whole admission; answers agree. To be removed by the incremental redesign.
- Passed: `./tools/check`, `git diff --check`. Synthetic only.

## Observation after incremental record (2026-10-20)

- Found while measuring: `Daily_book.observe_quantities` took reflected roots from the image's admission-time frontier. `put_entry`'s incremental path does not extend that frontier, so an entry added since the last full admission stayed unreflected and was counted twice (synthetic: wallet 1000, spend 100, observe 900 → 800, persisted after save/reload). The monolithic TUI publisher re-admits after saving, which masks it there; the Records append path keeps the incremental book and is exposed.
- Fix: roots now come from a fresh admission of the current data (observation already ended with a full admission). Regression test in `test/daily_book_tests.ml`.
- Passed: `./tools/check`, `./tools/tui --self-check` (36 PASS suites, exit 0), `git diff --check`. Synthetic only; latest-data paired comparison not executed (Core-only fix, no screen change). The incremental image's stale `source` frontier remains for other readers (`presentation/current_quantity_explanation.ml`, used from freshly loaded CLI books only).

## Startup, snapshot and in-memory response probe (2026-10-20)

- `./tools/startup-probe` on synthetic 1,000 / 36,500 / 109,500-entry books at `3bda3ca` (macOS x86_64, OCaml 5.3.0, cache not flushed). Results and limits: [stage 5](https://github.com/shumoku88-bit/bakhlo/blob/90a5867/docs/LONG_TERM_STORAGE_STUDY.ja.md#第5段階-起動スナップショットメモリ上応答2026-10-20). Measurement only; no product, storage or format change. No originals or private copies read.
- Key finding: replacing an existing entry (and every non-plain `put_entry`) re-admits the whole book, 796 ms in memory at 109,500 entries.

## Retained unapproved-Locus date and Merchant mutations (2026-10-20)

### Implemented boundary

- The synthetic fixture first admits an Actual and its paid-plan link, then removes one
  of that Actual's Loci from `approved-loci` while retaining the historical entry.
- Date-only publication no longer sends the whole transaction through generic
  `put_entry ~replace:true`. `Correct_entry_date` is a dedicated Core/Book-log
  operation carrying only entry ID and day. It validates the ID and calendar date,
  changes only `day`, and appends a replayable `correct-entry-date` record.
- Merchant publication remains a dedicated operation and now updates only Merchant
  metadata without reissuing the entry's Effects. Both incremental mutations retain
  entry identity, Effect keys and quantities, reversal/payment links, memo, original
  amount and the plan set. Their `Daily_book.Full` variants are the whole-book oracle.
- Generic correction and reversal are still Movement publications. Their existing
  `approved-loci` admission refusal is deliberately preserved; no broad exception was
  added to `put_entry`.

### Synthetic evidence that ran

- `test/daily_book_oracle_tests.ml` compares incremental date and Merchant results
  with `Daily_book.Full` on the retained unapproved-Locus fixture. `d` changes only
  the date and `m` changes only Merchant. Generic correction, a new entry and a new
  reversal using the removed Locus still return `locus-unapproved`. Invalid date,
  invalid/unknown ID, duplicate Merchant and invalid Merchant token remain refused.
  The randomized mutation oracle also admits at least 20 date corrections and checks
  every step against both a cold-loaded twin and the whole-book reference.
- `test/book_log_tests.ml` round-trips the new codec and replays it without reapproving
  historical Loci. Unknown targets and invalid dates stop replay at that record.
  `test/daily_file_tests.ml` confirms one valid append survives a cold load with all
  other entry fields unchanged, while refused date operations append no bytes.
- The TUI self-check drives the retained fixture through Actual: ordinary `c` opens
  but publication remains refused without a write; `x` remains in its editor and is
  refused without a write; `d` appends the dedicated operation and cold-loads the
  date-only result; `m` then cold-loads the Merchant result. The checks compare the
  retained entry, plan set, approved-Loci policy and relevant file bytes.
- `./tools/check`, `./tools/tui --self-check`, and `git diff --check` passed for this
  local slice.

### Performance (synthetic, `./tools/startup-probe`)

- At 109,500 entries (median of 21, filesystem cache not flushed):
  `correct_entry_date` 4.14 ms, `classify_merchant (first)` 4.03 ms,
  `put_entry replace old` 4.12 ms, save (append + fsync) 0.43 ms. Both new paths are
  dominated by the O(n) `entries_rev` rewrite shared with replace; within the 5 ms
  save target.

### Latest-data paired comparison (2026-10-20)

- Fresh `./tools/compare refresh` (LOAM open, originals not written, no user process
  terminated). Bakhlo working tree on `10a854d` with this slice uncommitted, Bonsai
  executable SHA-256 `f6034b5a96afc1eb18bb8860774e13e2b82f5b567f9a4ad608cbb0a4ac2d3b3b`;
  existing LOAM executable SHA-256
  `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3` (differs from the
  earlier recorded binary; source correspondence not certified).
- Target: one retained entry whose Effects use a Locus outside `approved-loci`, at
  120×36 and 80×24.
- Bakhlo, on a separate isolated copy of the selected capture per geometry: `c` reaches
  Preview and is refused (`A Locus is not admitted by the current book.`) without a
  write; `x` is refused (`locus-unapproved`) without a write; `d` publishes one
  `correct-entry-date` record; `m` publishes one Nonmerchant `classify-merchant`
  record. Cold `Book_log.load` (2 records) shows only that entry's date and Merchant
  changed, every other entry, the plans and `approved-loci` identical, and equals the
  `Daily_book.Full` result byte for byte. Exit compaction did not run (<200 records).
- LOAM, read-only on the same generation: from Transaction detail, `d` reaches the same
  date Preview (`Only the occurrence date changes.`, `[Publish date change]`) and `m`
  reaches the same Nonmerchant Preview; both were cancelled without publishing. LOAM
  exposes `d`/`m` only from Transaction detail, Bakhlo also from the Actual list.
- `../loam-data` household/config hashes and the LOAM comparison copy were identical
  before and after; the selected Bakhlo capture was unchanged; AI tmux server stopped;
  isolated trial copies deleted; `./tools/compare clean-copies` passed.

- Matching implementation `9697382`: [Core 39394378171](https://github.com/shumoku88-bit/bakhlo/actions/runs/39394378171) and [Bonsai TUI 39394378109](https://github.com/shumoku88-bit/bakhlo/actions/runs/39394378109) completed/success (synthetic CI).

### Limits

LOAM publication was not repeated on this generation (it was observed earlier on a
previous generation). A physical-terminal or IME run, human acceptance and
P7/power-loss behavior have **not been executed**.

## Daily Pace Selected day detail matches LOAM (2026-10-20)

### Implemented boundary

- `Daily_pace_trend.render_detail` now takes the period's samples and selected index
  and follows LOAM `DailyPaceTrend.detailLines`: full history (every day supported:
  Period, Display, Selected, Pace with `current`, change, activity, cycle basis,
  From/Through, disclosure, adjacent-day breakdown) or partial history (Supported k/n,
  `Selected D: pace` or `unavailable, not zero` plus cause, `previous day unavailable`,
  Origin, basis, disclosure, breakdown only between two known days). Wording, order,
  muted rows and LOAM's one-space indent match; the Daily Pace screen now keeps row
  styles instead of painting every detail row plain. Bakhlo's `Source:` row was removed.
- Intentional differences kept and checked: the scheduled-linked inflow/reversal row;
  a day's known activity beneath an unknown pace (never a dummy pool or zero); amounts
  use the Measure's decimal scale; Bakhlo's own unknown-cause text.
- Not changed: calculations, support conditions, chart, History, context, footer.

### Evidence

- New `pace-detail-full-history-loam-order`, `pace-detail-partial-history-loam-order`
  and `pace-detail-partial-unknown-cause-and-known-activity` compare exact rows and
  styles; existing wrap, huge/negative, scheduled-linked and dummy-pool checks adapted
  to the indent. `./tools/check`, `./tools/tui --self-check` (35 PASS) and
  `git diff --check` passed.
- Synthetic paired run on fresh copies of the 2026-10-19 zero-origin and anchor-only
  fixtures (Bakhlo SHA-256 `df3f62d46960917d28564e850d95f5df8f0b677900cddd1a93f9e757fccc11a7`,
  existing LOAM `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`,
  source correspondence not certified): zero-origin Selected day pane identical at
  120×36 and 80×24, whole screen identical at 48×14 and 32×9. Anchor-only differs only
  in the unknown-cause text, the intentional activity row, and LOAM's
  `History partial; unknown dates kept as gaps.` feedback row; elsewhere header
  `[?] why`/`[t] target` and chart drawing (known gaps). Fixture bytes unchanged.
- Latest-data paired comparison: fresh `./tools/compare refresh` (LOAM open, originals
  not written, no user process terminated); 12 walks (End, Up steps, periods 2–4,
  Home) at 120×36 and 80×24 plus three scrolled-to-end focused walks at 120×36. The
  Selected day pane was identical in all 15; remaining differing rows were only the
  header and chart rows. `../loam-data` hashes unchanged; AI tmux stopped; private
  captures deleted; `./tools/compare clean-copies` passed.

- Matching implementation `295e811`: [Core 39397549899](https://github.com/shumoku88-bit/bakhlo/actions/runs/39397549899) and [Bonsai TUI 39397549927](https://github.com/shumoku88-bit/bakhlo/actions/runs/39397549927) completed/success (synthetic CI).

### Limits

The `History partial` feedback row needs a screen-supplied feedback line in the Shell
contract and is left open. Physical terminal/IME, human acceptance and P7 were **not
executed**.

## Daily Pace chart follows LOAM Chart (2026-10-20)

### Implemented boundary

- New `tui/screens/pace/pace_chart.ml` ports LOAM `Tui.Chart` to exact Z values:
  `scaleFor` nice 1/2/5×10^n ticks with flat-series padding, `rowForValue` (floor from
  the low bound), `axisWidth`, qualified day-aligned braille sampling (no
  interpolation over unknown days or non-joinable edges), `●` known days, `◆` selected
  day, `┄` empty tick-row cells, and `withValueAxis` (`label ┤` on tick rows, `│`
  elsewhere). A continuous `line_rows` variant (LOAM `renderInRange` with the selected
  guide) is included for the Target plan.
- `Daily_pace_trend.render_chart` uses it with LOAM's trend geometry: plot height is
  the pane's inner height minus three when at least six, otherwise only the two summary
  rows. The old 12-row cap, Bakhlo's own line drawing and `·` grid were removed.
- Intentional differences: tick labels use the Measure's decimal scale; nice steps are
  not capped at 10^24, so huge values still chart where LOAM refuses.

### Evidence

- `./tools/check`, `./tools/tui --self-check` (35 PASS; the single-point tick check now
  expects LOAM's `┤`) and `git diff --check` passed.
- Synthetic paired run (fresh copies of the 2026-10-19 zero-origin and anchor-only
  fixtures; Bakhlo SHA-256 `dcec899cc8b3eb4591f096f703d507341eaf978d6b89637e35774fef1bcc8f12`,
  existing LOAM `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`):
  at 120×36, 80×24 and 48×14 for End, Up steps, `v` (dots), 30d End/Home+Right, Month
  and Cycle, every chart row is identical. Remaining rows: header `[?] why`/`[t] target`,
  unknown-cause text, the `History partial` feedback row, Bakhlo's `…` on a clipped
  48-column support line, Previous Cycle without a boundary, and Bakhlo's exact compact
  value at 32×9 (all pre-existing or recorded elsewhere). Fixture bytes unchanged.
- Latest-data paired comparison: fresh `./tools/compare refresh` (LOAM open, originals
  not written, no user process terminated); 7 walks at each of 120×36 and 80×24 (End,
  Up steps, dots, 30d, Month, Cycle, 30d Home+Right). All 14 whole screens were
  identical except header row 1. `../loam-data` hashes unchanged; AI tmux stopped;
  private captures deleted; `./tools/compare clean-copies` passed.

- Matching implementation `28d876b`: [Core 39399700062](https://github.com/shumoku88-bit/bakhlo/actions/runs/39399700062) and [Bonsai TUI 39399700046](https://github.com/shumoku88-bit/bakhlo/actions/runs/39399700046) completed/success (synthetic CI).

### Limits

Physical terminal/IME rendering of braille and ambiguous-width markers, human
acceptance and P7 were **not executed**.

## Daily Pace Target plan (2026-10-20)

User decision (2026-10-20): `[t] target` is needed. The `History partial` feedback row
and the missing-boundary Previous Cycle remain on hold until the user decides they are
needed.

### Implemented boundary

- New `tui/screens/pace/daily_pace_target.ml` follows LOAM `DailyPaceTarget` on the
  same current `Daily_book.daily_pace` answer: largest whole daily spend
  `floor((A - N·(R - k)) / k)`, pace path, optional hypothetical spend today, short
  dates (`26`, `11-02`) resolved to the first such day after today before cycle end,
  3/7/14/21/28/42-day horizons before the last day, earliest reachable day, `j/k`
  horizon selection, the option table's width layouts, result rows, and the target
  chart (`Pace_chart.line_rows` with the `target` guide row, purchase resampling).
- `t` opens it from Daily Pace; Esc/q close; nothing is written or reserved. Floating
  from 62×20 body cells (LOAM's threshold), otherwise an unframed full-body view with
  LOAM's title line.
- Intentional differences: inputs are whole units of the pace Measure (LOAM accepts JPY
  only); the caret is Bakhlo's `|` cell as in other forms; navigation and the
  read-only note stay in the Shell footer, so the floating pane is shorter and its chart
  has fewer rows at the same terminal size; the compact view drops LOAM's assumption
  footer lines so answer rows keep priority (the Shell footer states nothing is
  recorded).

### Evidence

- New checks: `pace-target-horizons-and-earliest`, `pace-target-dated-plan-and-purchase`
  (spend and exact pace path), `pace-target-unreachable`, `pace-target-refusals`
  (short date outside the cycle, impossible date, today, empty target, non-digit spend),
  and controller checks that `t` opens a modal painted within 120×36, 80×24, 48×14 and
  32×9 and that Esc/q close without changing the book bytes. `./tools/check`,
  `./tools/tui --self-check` (35 PASS) and `git diff --check` passed. A tmux probe put
  the terminal cursor on the caret in floating and compact views.
- Synthetic paired run (zero-origin fixture; Bakhlo SHA-256
  `caa25265c885c4363a300596c857dc2f3de5e75cdceaca82db13452aea9a2549`, existing LOAM
  `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`): LOAM 120×36 against
  Bakhlo 120×39 (same chart height) for table, `j`, dated plan, dated plan with spend,
  unreachable/out-of-cycle date, invalid key notice, empty form and full date: every
  pane row is identical except the active field's caret and LOAM's in-pane navigation
  row. At equal height the target chart is identical. Fixture bytes unchanged.
- Latest-data paired comparison: fresh `./tools/compare refresh` (LOAM open, originals
  not written, no user process terminated); six target walks (table, `j`, dated plan,
  dated plan with spend, unreachable target, M-D date). All non-input pane rows were
  identical; input rows differed only by the caret. `../loam-data` hashes unchanged; AI
  tmux stopped; private captures deleted; `./tools/compare clean-copies` passed.

- Matching implementation `7855f94`: [Core 39401386087](https://github.com/shumoku88-bit/bakhlo/actions/runs/39401386087) and [Bonsai TUI 39401386081](https://github.com/shumoku88-bit/bakhlo/actions/runs/39401386081) completed/success (synthetic CI).

### Limits

Physical terminal/IME, human acceptance and P7 were **not executed**.

## Daily Pace Why (2026-10-20)

User decision (2026-10-20): LOAM's `[?] why` is needed.

### Implemented boundary

- New `tui/screens/pace/daily_pace_why.ml` follows LOAM `DailyPaceWhy` over the same
  `Daily_book.daily_pace` answer: today's pace and the division (`free ÷ days left`,
  cycle end), Pool total with each balance (largest first) and its support (`recorded
  history` for zero-origin, `opening balance`, `observed` for a current assertion,
  otherwise `unsupported`, from the book's quantity query premise), Protected Scheduled
  with each occurrence by date, its payee (positive receiving Loci outside the pool, by
  label, else the plan ID) and `overdue, still open` before today, then Free through
  cycle end. Name and amount columns follow LOAM's widths. No arithmetic beyond the
  answer's own terms; an unavailable answer shows `Explanation unavailable (not zero)`.
- `?` opens it from Daily Pace (header now `[?] why  [w] what-if  [t] target`); j/k,
  arrows, Page, Ctrl-d/u and Home/End scroll; Esc/q/? close; nothing is written.
  Floating from 62×20 body cells (LOAM's threshold, width ≤ 90), otherwise an unframed
  body view with LOAM's title line. As with Target, navigation stays in the Shell
  footer, so fewer rows are visible at the same terminal size.

### Evidence

- New controller checks: unavailable pace shows the cause, never the terms; an available
  pace paints within 120×36, 80×24, 48×14 and 32×9; End/Up/Home/j scroll and Esc/q/?
  close without changing book bytes. `./tools/check`, `./tools/tui --self-check`
  (35 PASS) and `git diff --check` passed.
- Synthetic paired run (zero-origin and anchor-only fixtures; Bakhlo SHA-256
  `106dfd888be5e548ad7489c10a65ab7615250666ce1e488107499d65f053da47`, existing LOAM
  `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`) at 120×36: every
  pane row identical (`recorded history` and `observed` routes, overdue deduction)
  apart from LOAM's in-pane navigation row. Fixture bytes unchanged.
- Latest-data paired comparison: fresh `./tools/compare refresh` (LOAM open, originals
  not written, no user process terminated). At 120×36 (open, End, j j, PageDown) all
  non-blank pane rows are identical. At 80×24 LOAM shows 19 body rows and Bakhlo 16, so
  scrolled windows differ; Bakhlo at 80×27 (19 rows) against LOAM 80×24 after End
  showed identical pane content (only background outside the pane differed).
  `../loam-data` hashes unchanged; AI tmux stopped; private captures deleted;
  `./tools/compare clean-copies` passed.

### Limits

Physical terminal/IME, human acceptance and P7 were **not executed**.

Matching implementation `38b7155`: [Core 39402388604](https://github.com/shumoku88-bit/bakhlo/actions/runs/39402388604) and [Bonsai TUI 39402388686](https://github.com/shumoku88-bit/bakhlo/actions/runs/39402388686) completed/success (synthetic CI).

User decision (2026-10-20), after the differences were explained: keep Bakhlo's
behavior for the partial-history feedback row (not shown; the same caution is in the
Trend summary, History `unknown` rows and the Detail `Supported` line) and for a
Previous Cycle without a boundary (stay on the current period and report the cause).
Both are recorded as intentional differences; no code changed.

## Daily Pace What-if follows LOAM (2026-10-20)

### Implemented boundary

- The form-based What-if (amount field, Simulate button, result in the notice) was
  deleted. New `tui/screens/pace/daily_pace_what_if.ml` follows LOAM
  `DailyPaceWhatIf`: a read-only pane priced as you type over the same current
  `Daily_book.daily_pace` answer — Current, Remaining days, Already protected
  Scheduled, then After purchase (`floor((available - amount) / days)`), Daily change
  and Available after, with LOAM's footer lines. Esc/q close; nothing is written.
  Floating 18 rows from 62×20 body cells (width ≤ 86), otherwise covering the body.
- Intentional differences: any pool Measure works, with `.` accepted only for Measures
  with decimals (LOAM: JPY only); the caret is Bakhlo's `|`; an unavailable answer
  still names the book's Measure in the input label.

### Evidence

- Checks rewritten for the overlay: missing pool and unknown balance show `Current
  projection unavailable (not zero)` with the cause and no After purchase; typed `2000x`
  shows After purchase/Daily change/Available after and the digits-only notice; the
  observation scenario prices 2000 without changing the book; the negative case still
  floors to `-1 jpy/day` without clamping. `./tools/check`, `./tools/tui --self-check`
  (35 PASS) and `git diff --check` passed.
- Synthetic paired run (zero-origin fixture; Bakhlo SHA-256
  `a4809a1e4ca144768b254b318dc5cdeba77649228ee5b035ffd900c1d28e648f`, existing LOAM
  `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`) at 120×36: empty,
  2000, invalid key, six nines and Backspace — every pane row identical except the
  input row's caret (`_` empty in LOAM).
- Latest-data paired comparison: fresh `./tools/compare refresh` (LOAM open, originals
  not written, no user process terminated); four walks at each of 120×36 and 80×24.
  Every non-input pane row identical. `../loam-data` hashes unchanged; AI tmux stopped;
  private captures deleted; `./tools/compare clean-copies` passed.

- Matching implementation `223e971`: [Core 39403550358](https://github.com/shumoku88-bit/bakhlo/actions/runs/39403550358) and [Bonsai TUI 39403550597](https://github.com/shumoku88-bit/bakhlo/actions/runs/39403550597) completed/success (synthetic CI).

### Limits

Pool setup (`c`) was not compared in this slice. Physical terminal/IME, human
acceptance and P7 were **not executed**.

## Daily Pace pool picker follows LOAM (2026-10-20)

User decision (2026-10-20): replace the comma-separated pool editor with LOAM's picker.

### Implemented boundary

- The form-based pool editor (Locus tokens typed with commas, old/new review form) was
  deleted. New `tui/screens/pace/daily_pace_pool.ml` follows LOAM
  `DailyPacePoolSetup`: `Daily Pace / Spendable pool (<measure>)`, candidates are only
  coordinates with an exact current balance, `j/k` move, Space toggles, Enter reviews
  (empty selection refused), review Enter saves, `Esc/e` edits, `Esc/q` cancels. Rows and
  wording match LOAM's choose and review views.
- Candidate order follows LOAM's rule as far as Bakhlo's book can express it: grouped
  by support (zero-origin, opening, current observation), each in first-appearance order
  over retained entries (any Locus, as balances do), then admitted Loci without one.
- Kept from Bakhlo: the save still goes through `Save_config` with the bytes captured at
  open (a changed file refuses), a cancelled picker resumes for the same Measure, and
  Commands → Daily Pace / spendable accounts opens the same picker.
- Intentional differences: review refuses to save unless every review row is visible
  and unclipped (LOAM truncates the chosen list); balances from the earlier pool that are
  no longer exact-current are dropped and named in the picker notice and the review
  (LOAM refuses to open); refusal notices wrap instead of being ellipsized; an unreadable,
  malformed or foreign-Measure file opens with its cause and refuses review.

### Evidence

- Checks rewritten for the picker (driven through painted rows): existing pool pre-checked,
  empty refusal, review before write, Esc/cancel/Commands draft resume, narrow and
  clipped review refusal, write failure (lock) and stale file refusal keep the draft,
  explicit save and cold reopen, foreign/malformed/unreadable refusal, dropped balances
  named, missing file created, period file never invented, ledger and boundaries
  unchanged. `./tools/check`, `./tools/tui --self-check` (35 PASS) and
  `git diff --check` passed.
- Synthetic paired run (zero-origin fixture; Bakhlo SHA-256
  `a5cd88fb92125750204fe6db18d7140ac308120e61bbf73a77a6336a8af2fe0f`, existing LOAM
  `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`): LOAM via Commands →
  Household setup → Daily Pace / spendable accounts, Bakhlo via `c`: open, move, toggle,
  review and back are row-identical apart from Bakhlo's two Shell footer rows. A first
  attempt drove Bakhlo with LOAM's Commands key path, which lands elsewhere because the
  Commands order differs (recorded under UI-02); that attempt saved a theme only in the
  scratch fixture copy.
- Latest-data paired comparison: fresh `./tools/compare refresh` (LOAM open, originals
  not written, no user process terminated); read-only walks (open, move, toggle, review,
  back; never confirming a save) at 120×36 and 80×24. Rows identical except one
  candidate's position, which depends on LOAM's internal event-memory order. Comparison
  copy bytes and `../loam-data` hashes unchanged; AI tmux stopped; private captures
  deleted; `./tools/compare clean-copies` passed.

- Matching implementation `3461305`: [Core 39406808758](https://github.com/shumoku88-bit/bakhlo/actions/runs/39406808758) and [Bonsai TUI 39406808781](https://github.com/shumoku88-bit/bakhlo/actions/runs/39406808781) completed/success (synthetic CI).

### Limits

Physical terminal/IME, human acceptance and P7 were **not executed**.

## Actual workspace layout and details parity with LOAM (2026-10-20)

### Implemented boundary

- `tui/screens/actual/actual_workspace.ml`: aligned geometry and formatting with LOAM `Loam/Tui/ActualWorkspace.lean`:
  - `wide` threshold set to `writable >= 98 && panel_height >= 16`.
  - Context rows (`context_rows = 2` when body capacity >= 5, 1 when >= 4, 0 otherwise) with LOAM-styled heading and date line.
  - Table row and amount formatting aligned (`format_money`, no unary `+` on positive amounts, consistent column spacing).
  - Detail pane (`detail_capacity` 8/10/12, `detail_raw_lines` matching LOAM order: Date, Effects, Blank, Description, ID, followed by Bakhlo's retained facts).
  - Search caret placement on context row.
- `tui/protocol/screen.mli`, `tui/protocol/screen.ml`: added `draft_retained : bool` to `Screen.env`.
- `tui/shell/screen_registry.ml`: updated `Actual` owner layout to `Screen.Workspace`.
- `tui/shell/shell_dispatch.ml`: populated `draft_retained = has_record_draft state`. Added `owner_layout` helper so that modal overlay geometry dynamically adheres to the underlying route's layout (`Screen.Workspace`), resolving modal overlay clipping over terminal feedback lines.
- `tui/screens/actual/test/actual_workspace_checks.ml`: updated expectations for positive amounts (`500 jpy` instead of `+500 jpy`) and empty range (`0/0`).
- `tui/scenarios/actual_integration_checks.ml`: updated expected list page calculation for the new context/panel geometry, and navigated to end of details for low-priority metadata assertions in 8-row detail pane.
- `tui/scenarios/publication_integration_checks.ml`: adjusted wide two-pane title check (`Actuals` and `Details`).

### Evidence

- Unit and integration checks passed:
  - `./tools/check`: 1008 test cases passed.
  - `./tools/tui --self-check`: all Bonsai scenarios and terminal checks passed (including overlay feedback visibility under both Standard and Workspace route layouts).
  - `git diff --check`: clean (no trailing whitespace or conflict markers).
- Matching implementation `16d8cc6`: [Core 39412295863](https://github.com/shumoku88-bit/bakhlo/actions/runs/39412295863) and [Bonsai TUI 39412295871](https://github.com/shumoku88-bit/bakhlo/actions/runs/39412295871) completed/success (synthetic CI).

### Latest-data paired comparison (added after the commit)

- Fresh `./tools/compare refresh` (LOAM open, originals not written during the copy, no user
  process terminated). Bakhlo SHA-256
  `44147638f67baef28f86cf979c116c4823134b58e473dabf51862e2db347d5cf` (main `cb258c6`),
  existing LOAM `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`.
  Read-only walks (open, j, i, h, h+j, s, f) at 120×36 and 80×24.
- At 80×24 every row is identical except the Details bottom label (`▼ [i] more`, because
  Bakhlo appends the Merchant line) and the footer `[d] date [m] merchant`. At 120×36 the
  same two, plus the Loci list order: both use first appearance over current records, but
  LOAM moves a corrected record to its correction position while Bakhlo keeps the same
  ID at its original position (the same cause as the pool candidate order). Recorded as
  an intentional consequence of same-ID correction, not reproduced.
- `../loam-data` hashes differed from the morning values (ordinary LOAM recording in
  between). A before-run hash was **not captured** for this walk, so before/after equality
  of the originals is not claimed for it; every walk used the private copies. AI tmux
  stopped; private captures deleted; `./tools/compare clean-copies` passed.

### Limits

Physical terminal/IME, human acceptance and P7 were **not executed**.

## Daily Pace chart selected day vertical guide (2026-10-20)

Correction (later the same day): LOAM's Trend chart uses `renderQualifiedInRange`, which draws
no selected-day guide; a synthetic paired capture after `h h h` at 120×36 shows the `│`
column only in Bakhlo. This guide is therefore a deliberate Bakhlo addition (the day
cursor stays visible on gaps and while moving), not LOAM parity. Before it, every chart row
matched LOAM ([chart comparison](#daily-pace-chart-follows-loam-chart-2026-10-20)).

### Implemented boundary

- `tui/screens/pace/pace_chart.ml`: updated `qualified_rows` to render a vertical guide line (`│`) along the selected day column (`col = selected_x`), and short local horizontal guides (`─`) around the selected point, matching LOAM's `renderInRange` / `renderManyInRange` design principles.
- Graph line braille glyphs take precedence over guide lines so underlying curves are not interrupted.
- When the selected day has no value (unavailable/hole), the vertical guide `│` remains visible on that column, making the date cursor's horizontal position explicit.
- `tui/scenarios/pace_integration_checks.ml`: added assertions verifying vertical guide visibility for both normal selected points and missing/unavailable days.

### Evidence

- Unit and integration checks passed:
  - `./tools/check`: 1008 test cases passed.
  - `./tools/tui --self-check`: all 35 Bonsai scenario suites passed.
  - `git diff --check`: clean (no trailing whitespace or conflict markers).
- Matching implementation `2a6983c`: [Core 39415381331](https://github.com/shumoku88-bit/bakhlo/actions/runs/39415381331) and [Bonsai TUI 39415380979](https://github.com/shumoku88-bit/bakhlo/actions/runs/39415380979) completed/success (synthetic CI).

### Limits

Physical terminal/IME, human acceptance and P7 were **not executed**.

## Record Ctrl-U enables unresolved recording as in LOAM (2026-10-20)

User decisions (2026-10-20): correction (`c`) should allow LOAM's Locus/row changes;
reversal keeps Bakhlo's `x`; Ctrl-U should follow LOAM's enable flow.

### Implemented boundary

- `tui/shell/record_session.ml`: Ctrl-U while the ordinary `suspense` Locus is not
  admitted opens LOAM's `unresolvedEnableView` (Household vocabulary: Admit ordinary Locus:
  suspense; Not a Movement publication; `[Enable unresolved recording]`). `e/E`/Backspace
  return to the draft, Esc holds the draft, Enter returns `Enable_unresolved` (refused while
  writes are blocked).
- `tui/shell/shell_input.ml`: the Shell publishes only `Add_locus "suspense"` through the
  existing single writer (`commit_add_locus`), then returns to the same draft and fills the
  remainder, reporting `Unresolved recording enabled; remainder filled.` or the fill cause;
  a refusal returns with `Unresolved recording was not enabled: <cause>`. No Movement is
  recorded by this step.

### Evidence

- Unit checks (enable view and bounds at four sizes, `e` return, Enter request, blocked
  writes, failure cause, post-enable notice) and a Shell scenario: the example book gains
  `suspense` in memory and after cold load, the draft stays open with a `+200` suspense
  remainder, and no entry is added. `./tools/check`, `./tools/tui --self-check` (36 PASS),
  `git diff --check` passed.
- Synthetic paired run at 80×24 (Bakhlo SHA-256
  `ad318a42d931e4e1f3c492256483ffc05b1cf9a302b768d77e2b99452323e1d0`, existing LOAM
  `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`): the enable view has
  the same wording and panels; Bakhlo paints it in its floating Record surface.
- Latest-data read-only run (open Record, Ctrl-U, no Enter): `suspense` is already admitted
  in the household, so both show the same `Complete every current Locus before filling the
  unresolved remainder.` (an earlier ad-hoc grep wrongly reported it absent). Originals'
  hashes equal before and after; private captures deleted; `clean-copies` passed.
- Found while comparing: current LOAM opens Record in a one-line quick-entry mode
  (`Description, then total and Loci if they differ`) with Tab to the full form; Bakhlo opens
  the full form. Recorded in the cutover ledger as a Record difference.

- Matching implementation `f9ebb4a`: [Core 39427583643](https://github.com/shumoku88-bit/bakhlo/actions/runs/39427583643) and [Bonsai TUI 39427583669](https://github.com/shumoku88-bit/bakhlo/actions/runs/39427583669) completed/success (synthetic CI).

### Limits

Physical terminal/IME, human acceptance and P7 were **not executed**.

## Actual correction edits Loci and rows as in LOAM (2026-10-20)

User decision (2026-10-20): correction (`c`) follows LOAM.

### Implemented boundary

- `tui/shell/record_session.ml`: the correction editor no longer locks posting Loci,
  signs or rows (add/drop rows and Ctrl-U work as in Record). As in LOAM Correction the
  date is kept: labelled `Date (kept)`, skipped by focus, and typing there refuses with a
  pointer to `d`. Title `Correction / Edit`, a `Target: <id>` row, unsigned positive
  amounts in the prefilled rows.
- Effect keys: a prefilled row keeps its key only while its Locus equals the original
  posting's Locus with that key; a changed Locus publishes as a new posting. The same
  entry ID, payment link and existing refusals (exchange/reversal-linked entries) remain.
- Kept Bakhlo difference: Ctrl-O can still show and edit the retained original amount in a
  correction (LOAM refuses Ctrl-O there).

### Evidence

- Unit checks: sign editable, row addable, `Date (kept)` label, focus skips the kept date,
  a keyed entry whose first posting moves to another Locus drops only that key, keeps the
  second key and the Scheduled payment link through `Daily_book.put_entry ~replace:true`.
  Shell scenario: correcting the description keeps the same row and date after cold load;
  a second correction changes the first posting's Locus under the same ID and cold-loads.
  `./tools/check`, `./tools/tui --self-check` (36 PASS), `git diff --check` passed.
- Synthetic paired view at 80×24 (Bakhlo SHA-256
  `ac3f299bd660bff27f9e19352b73a217bded4c77f12ce27f9552a357ff4c72c7`, existing LOAM
  `312467cd9af30778873bb9afabf0d87143e874d67c828e828c42f8573b8840c3`): same `Date (kept)`,
  postings and amounts; Bakhlo paints in its floating Record surface.
- Latest-data read-only paired view (two Actuals; open correction only, no save): every
  field row (date kept, description, Measure, postings, amounts, Target) identical except
  Bakhlo's `|` caret on the focused field. Originals' hashes equal before and after;
  private captures deleted; `clean-copies` passed.

- Matching implementation `510e77e`: [Core 39428509940](https://github.com/shumoku88-bit/bakhlo/actions/runs/39428509940) and [Bonsai TUI 39428510276](https://github.com/shumoku88-bit/bakhlo/actions/runs/39428510276) completed/success (synthetic CI).

### Limits

No real-data correction was saved. Physical terminal/IME, human acceptance and P7 were
**not executed**.

## Private household text kept out of the repository (2026-10-20)

User decision (2026-10-20): no private household text may enter this repository.

- Manual audit first: every tracked file and the full history of 434 commits (including
  commit messages) were searched for Locus names, memos, entry identifiers and original
  hashes seen in the private comparison copies; none was found. `scratch/` is ignored and
  has no tracked file; `examples/` books are synthetic.
- New `tools/privacy-scan`: takes the quoted strings of the ignored private book copies
  under `scratch/` as tokens and refuses any whole-word match in changed and new files
  (`--all`: every tracked and new file). Matches are reported as file, line and byte
  length only. Generic words that also occur in the repository (25, e.g. `food`, `wallet`,
  `rent`, synthetic `record-1`) were reviewed and recorded in the ignored
  `scratch/privacy-baseline.txt`, so no private-derived list is committed. Without private
  copies (CI) it reports `not executed`.
- `./tools/check` now ends with the changed-file scan. Measured: `--all` 84 s over 504 files,
  changed-file mode under 1 s. A planted private token in an untracked file was detected
  (exit 1, reported as `12 bytes` only) and the file was removed.

## Record quick capture as in LOAM (2026-10-20)

Closes the difference found during the Ctrl-U comparison: LOAM opens a new Record in a
one-line quick-entry mode.

### Implemented boundary

- New `tui/shell/quick_capture.ml/.mli`: one line of description, optional total and
  optional Locus words (token, label or unique prefix). Past current, unreversed,
  single-Measure entries with the same description are proposed as templates (most used
  among the latest ten, then latest); a total equal to a template's replays it exactly,
  any other total keeps only its Loci. A named Locus replaces the payer/part with the same
  accounting role or joins its side; the one unamounted line per side takes what the total
  leaves. A leading date word (`2026-10-18`, `10-18`, `10/18`) dates the record; an unreal
  date is passed to Record unchanged so Record's own validation refuses it.
- Nothing is retained or published by quick capture: a complete balanced line goes to
  Record's own Preview (same gates), anything else (or Tab/Ctrl keys) to the full form
  prefilled with focus on the first missing field. Unknown words are shown as
  `Not understood` and never ignored. Amounts are exact quanta at the Measure's scale.
- `record_session.ml`: only a new Record starts in quick capture; edit, Pay, Plan and
  correction open the full form as before. Esc keeps the typed line as a retained draft.
- Kept Bakhlo difference: the default date is Record's day (the shown/selected day), as
  Bakhlo's full form already does; LOAM's quick capture uses today.

### Evidence

- `tui/shell/test/quick_capture_checks.ml` (cases of LOAM `checkQuickCapture`, synthetic):
  prefix then substring suggestions, reversed and other-Measure records not learned, usual
  split replayed, named part/payer, matching-total preference, open split focus, unknown
  word refusal, roleless Loci, date words, Tab/Esc, bounded view with one caret at 32×9,
  48×14 and 80×24.
- Shell scenario: after one ordinary Record, `r`, `Eng`, Enter, Enter reaches
  `Record / Preview`; Publish appends a second entry with a new ID and the same memo and
  postings after cold load. Existing scenarios now press Tab to reach the full form.
- `./tools/check` (privacy scan no match), `./tools/tui --self-check` (38 PASS),
  `git diff --check` passed.
- First push `697f92e`: Core CI success, Bonsai TUI CI failed in the Linux PTY matrix
  (`tools/ci_tui_pty.py` still expected the full form right after `r`). The PTY script now
  waits for quick capture and presses Tab; the local native PTY matrix passed (4 dimensions
  and the narrow Preview refusal).
- Matching CI: Core [39446688761](https://github.com/shumoku88-bit/bakhlo/actions/runs/39446688761)
  success on `697f92e`; Bonsai TUI [39447458903](https://github.com/shumoku88-bit/bakhlo/actions/runs/39447458903)
  success on `26829b8` (same code plus the PTY script; Core is not triggered by that path).
- Latest-data paired comparison on fresh generation `capture-1792510023-32503-293b919a`
  at 120×36 and 80×24 (read-only flows: `r`, prefix typing, description completion via Enter,
  template proposal, ↓ navigation between templates, Enter to Preview, Esc to Home; partial
  line with total and Locus words):
  - Prefix suggestions, counts (e.g. 158×, 2×, 1×) and recency dates match LOAM exactly.
  - Template proposal rankings, postings, split amounts and totals match LOAM exactly.
  - Enter reaches identical Record Preview (amounts, Loci, signed postings, date).
  - Esc returns Home without mutating the book or authority bytes (verified by SHA-256 before
    and after). AI tmux sessions closed, `clean-copies` passed.
  - Differences observed during paired comparison:
    1. Presentation: LOAM renders quick capture inside a bounded framed panel
       (`╭ Record ──...╮`) with the footer inside the box; Bakhlo renders it full-width
       without a box frame, and the footer is pinned to the terminal bottom.
    2. Comparison environment dependency: `tools/compare_capture.ml` does not yet extract
       `household.loam`'s `AccountingRole` section into `config/accounting-roles.tsv`;
       with the roles provided, Locus role replacement (e.g. paying Asset replacement) matches
       LOAM identically.

### Limits

Synthetic paired comparison against LOAM, physical terminal/IME, human acceptance and P7
were **not executed**.

## Record quick capture framed modal (2026-10-21)

### Boundary

- Presentation only: quick-capture parsing, template ranking, default Record date,
  publication gates, full-form Record layout and household storage are unchanged.
- `Quick_capture.surface` describes the shared frame/caret rectangle. With no
  warning, 80×24 uses a 75×14 frame at (2,4); 120×36 uses 80×14 at (19,10).
  The footer stays inside the frame; 48×14 and 32×9 use the unframed available area.
- The Shell no longer detaches a framed quick capture's last two rows. Compact
  feedback stays above the two navigation rows. A frame moves upward or gives way
  to compact rendering when it would cover household feedback (including 57×16).
- Reused Record's existing frame helpers; no dependency, Core, format, CLI or
  accounting-role configuration change.

### Exercised evidence

- Reproduced the unframed top-of-screen capture and detached bottom footer on the
  pre-change native binary at 80×24 with `examples/daily-book.sexp`.
- `./tools/check` passed (Core build/tests and changed-file privacy scan).
- The first native build caught a missing `Quick_capture.surface` parameter type;
  after that fix the existing `Bonsai-long-warning-visible-above-footer` regression
  caught compact feedback below the footer. Both causes were fixed, not bypassed.
- Final `./tools/tui --self-check` passed, including the existing warning-rendering
  matrix and new frame/footer, non-ASCII caret, Shell overlay, compact roundtrip,
  and 57×16 warning-priority checks.
- `python3 tools/ci_tui_pty.py
  _build/daily-bonsai/_build/default/tui/app/bonsai_daily.exe
  examples/daily-book.sexp` passed: four PTY dimensions, keyboard/resize/cold reload,
  exact quantities, narrow Record Preview Publish refusal, and unchanged authority.
- Actual tmux surfaces, synthetic inputs only: direct existing LOAM binary with a
  fresh `loam init` household, and Bakhlo with the tracked synthetic Daily fixture.
  Compared empty quick-capture frames at 80×24 / 120×36 and unframed fallback at
  48×14. Bakhlo also exercised 32×9, resize back to the frame with typed text, Tab
  to the full form, Esc/resume of both full and quick drafts, and a long Japanese
  quick draft whose caret remained inside the frame. This was a geometry comparison,
  not a paired accounting-answer or history-template comparison.
- Both synthetic household files had identical SHA-256 before and after. Only
  AI-owned tmux sessions were used; no original household or private copy was read.
- Built Bakhlo binary SHA-256:
  `c5249f62d59c1e04d83cd1230150311c95c37dcfc803a441d47fc6c5a996c3a8`;
  existing LOAM binary:
  `4a413fa3df08c1490eb30e50e19b7b5fe4149a488e693a26696e68ba4cbe348c`.
- Independent review identified the type annotation, compact feedback ordering,
  framed warning occlusion and impossible compact-footer text assertion; all were
  addressed, and the Shell boundary regression was added.
- `./tools/privacy-scan --all` passed with no match; `git diff --check` passed.
- Pushed `810abc9` to `main`; matching-SHA Core CI
  [39461777012](https://github.com/shumoku88-bit/bakhlo/actions/runs/39461777012)
  and Bonsai TUI CI
  [39461777079](https://github.com/shumoku88-bit/bakhlo/actions/runs/39461777079)
  both succeeded. AI-owned synthetic trial directories and tmux sessions were removed.

### Limits

Latest-data paired comparison, physical terminal/IME, human acceptance and P7 /
power-loss qualification were **not executed**. AccountingRole extraction was not
part of this modal slice; its subsequent verification follows below. No cutover.

## Comparison AccountingRole capture (2026-10-21)

### Boundary

- `tools/compare_capture.ml` now validates the required household `AccountingRole`
  section and writes its exact body to each new generation's
  `config/accounting-roles.tsv`. No TUI, Core, CLI or dependency change.
- LOAM's production AccountingRole authority requires the section and refuses
  malformed maps. Capture uses the same exact version-1 header, trailing newline,
  row shape, role tokens and unique-Locus requirement. Header-only empty maps are
  valid; missing maps are not empty claims and no frozen standalone fallback is used.
- Bakhlo's existing role readers trim Loci. Capture therefore refuses leading or
  trailing whitespace in a Locus rather than silently change its identity. It does
  not infer roles or add a new Locus-admission policy.
- Source and LOAM-view config copies remain exact, including conflicting standalone
  role files. Only the Bakhlo generation config uses household roles. Existing
  `ui-config` trial overrides remain higher priority and are never deleted.
- Role refusal occurs before a new capture is published; old CURRENT and trial
  bytes remain unchanged. Copy cleanup keeps the derived role file.

### Exercised evidence

- Reproduced with an isolated synthetic household containing AccountingRole:
  pre-change refresh succeeded but generated no `accounting-roles.tsv`.
  Actual 80×24 quick capture then treated a replacement Asset as the receiving side
  instead of replacing the payer. No publication was attempted.
- Existing `./tools/compare self-check`, `./tools/check` and
  `./tools/tui --self-check` all passed on the implementation's first run.
  After removing an unnecessary whole-body copy from the parser and adding two
  framing regressions, the final `./tools/compare self-check` passed again.
- Extended the existing synthetic capture self-check: exact body placement,
  conflicting standalone preservation, required missing-section refusal, unknown
  role, duplicate Locus, wrong version, missing trailing newline, malformed field
  count, whitespace-identity refusal, explicit empty-map publication, old CURRENT /
  trial preservation, and derived config surviving cleanup.
- Actual native TUI on the corrected synthetic generation: role-aware payer
  replacement, exact signed-posting Preview at 80×24 / 120×36, Escape without saving,
  then raw-copy cleanup and cold reopen at 48×14 with the same correct replacement.
  No manual role setup was used. The old incorrect generation was preserved.
- Synthetic book bytes equalled imported bytes after the non-saving flows;
  source household SHA-256 was unchanged before and after. Both raw standalone
  config copies matched their synthetic source bytes before cleanup.
- `./tools/privacy-scan --all` and `git diff --check` passed. AI-owned tmux
  sessions exited; the isolated `/tmp` smoke fixture was removed. No existing
  private comparison trial or user UI configuration was touched.
- Independent review: Ship. Its suggested regression for a present zero-length
  body was added, keeping missing, malformed-empty and explicit empty-map distinct.
- Pushed `97d8dbb` to `main`; manually dispatched matching-SHA
  [Core CI 39466812732](https://github.com/shumoku88-bit/bakhlo/actions/runs/39466812732)
  and [Bonsai TUI CI 39466819241](https://github.com/shumoku88-bit/bakhlo/actions/runs/39466819241)
  both succeeded. These standard workflows do not exercise the private converter;
  the capture tool itself was compiled and exercised by the local synthetic checks.

### Limits

Latest-data paired comparison, real household access, physical terminal/IME,
human acceptance and P7 / power-loss qualification were **not executed**.
The private converter remains an existing local prerequisite; this is not a
standalone full-household importer or operational cutover.

## Manage Loci paired comparison and list paging (2026-10-21)

### Change

- `tui/screens/loci/loci_screen.ml`: in the Loci list, PageDown / Ctrl-d, PageUp /
  Ctrl-u and End reset the selection to the first Locus (bug). They now move by one
  page, stop at the last Locus, and End selects the last one; Home selects the first.
  The detail pane keeps its scroll behaviour. LOAM ignores these keys on its Manage Loci
  screen; Bakhlo keeps paging as an intentional addition.
- Regression in `tui/scenarios/setup_integration_checks.ml` (synthetic): End, k then
  PageDown, PageUp, Home, PageDown from the first item. With the screen fix reverted the
  self-check fails at `loci-end-selects-last`.

### Evidence

- `./tools/tui --self-check` (38 PASS), `./tools/check` (privacy scan no match).
- Latest-data paired comparison on fresh generation `capture-1792518557-51651-293b919a`,
  read-only flows at 120×36 and 80×24: Commands → Household setup → Manage Loci; list
  navigation; LOAM roles view (Tab), history support view (Shift-Tab); Bakhlo admit form
  (`n`) opened and cancelled. After rebuilding, Bakhlo End / PageDown / PageUp / Home
  selected the last / last / previous page / first Locus on the copy.
  - Same admitted count and list order (admission order) in both.
  - LOAM opens Manage Loci directly on the admit form (token field above, ↑/↓ inspect
    10 admitted rows, `Admission creates no label, role, route, rename, or alias.`).
    Tab opens initial AccountingRole assignment for unused Loci only; Shift-Tab opens
    History Support / Complete Since. Bakhlo shows a list with a detail pane and opens
    admission as a modal with an optional role.
  - At 80×24 the Bakhlo list hides the label column (`…`) and the detail pane wraps in
    the middle of words; LOAM shows token and label.
  - Commands / Household setup: LOAM also lists `Observe quantities`; Bakhlo also lists
    Theme and Home / Bonsai.
  - During the LOAM run a stray key put a blank token into LOAM's admit field and reached
    its Preview; it was left with Esc without publishing and the field was cleared.
    Whether LOAM refuses a blank token at publication was not tested.
- Household/config SHA-256 equal before and after; the comparison book copy was
  unchanged. AI tmux sessions closed, `clean-copies` passed.
- Pushed `a81e5b8` to `main`; matching-SHA
  [Core CI 39471308226](https://github.com/shumoku88-bit/bakhlo/actions/runs/39471308226)
  and [Bonsai TUI CI 39471308113](https://github.com/shumoku88-bit/bakhlo/actions/runs/39471308113)
  both succeeded.
- Not fixed here: Attention's `End` has the same overflow pattern (`move` with
  `max_int` wraps to the first item when the selection is not the first).

### Limits

Display-name screens, saves, physical terminal/IME, human acceptance and P7 were
**not executed**.

## Manage Loci initial role assignment and 80-column list (2026-10-21)

User decision (2026-10-21): keep Bakhlo's list + detail Manage Loci; adopt LOAM's
initial-only AccountingRole rule; fix the 80×24 list and detail.

### Change

- `tui/screens/loci/loci_screen.ml`: `r` and its submission, and a role chosen while
  admitting, are refused for a Locus named by any Actual entry or Scheduled plan
  (`Already used by Actual or Scheduled evidence; role cannot be assigned.`) and for a
  Locus that already has a role (`... roles are never replaced.`). The role form starts
  unselected and refuses saving no role. Unused `index_of_role` removed.
- List columns fit the list pane: token and role widths come from the shown Loci, and the
  role column is dropped before the label when the pane is narrow (the detail names the
  role). Tokens are never clipped. Detail prose wraps between words at its indent, with the
  shared character wrap only for a word wider than the room.

### Evidence

- `tui/scenarios/setup_integration_checks.ml` (synthetic): replacement refused and the
  role kept; a used Locus refused; a Locus admitted without a role gets one, an empty
  choice is refused, a second `r` is refused; at 80×24 the list row keeps the label and
  the detail keeps `represents` whole. Reverting the column fit or the word wrap fails
  `loci-80x24-list-keeps-label` / `loci-80x24-detail-wraps-between-words`.
- `./tools/check` (privacy scan no match), `./tools/tui --self-check` (39 PASS),
  `git diff --check` passed.
- Bakhlo on the retained comparison book (generation `capture-1792518557-51651-293b919a`,
  read-only): 80×24 list shows token and label, detail wraps between words, `r` on a used
  Locus shows the refusal on one line; book SHA-256 unchanged. LOAM was not rerun (its
  copy had been cleaned); the rule follows LOAM's observed `Virgin Locus only; no role
  replacement` screen from the comparison above.
- Pushed `710129f`; matching-SHA
  [Core CI 39475744588](https://github.com/shumoku88-bit/bakhlo/actions/runs/39475744588)
  and [Bonsai TUI CI 39475744583](https://github.com/shumoku88-bit/bakhlo/actions/runs/39475744583)
  both succeeded.

### Limits

Correcting a wrong role is no longer possible in the UI, as in LOAM. Physical
terminal/IME, human acceptance and P7 were **not executed**.

## Attention End selection overflow (2026-10-21)

- `tui/screens/attention/attention_screen.ml`: `move` bounded the step after adding it, so
  End (`+max_int`) wrapped to a negative index whenever the selection was not the first
  item and selected the first item instead of the last. The step is now bounded first,
  as in `Record_browser.move`.
- Regression in `tui/scenarios/attention_integration_checks.ml` (synthetic, two open
  items): j then End selects the last item, Home the first. It failed at
  `attention-end-from-second-selects-last` before the fix.
- `./tools/check`, `./tools/tui --self-check` (39 PASS) and `git diff --check` passed.
- Pushed `e76dec1`; matching-SHA
  [Core CI 39476432040](https://github.com/shumoku88-bit/bakhlo/actions/runs/39476432040)
  and [Bonsai TUI CI 39476432576](https://github.com/shumoku88-bit/bakhlo/actions/runs/39476432576)
  both succeeded.
  Latest-data comparison, physical terminal and P7 were **not executed**.

## Accounting represents evidence coordinates (2026-10-21)

### Difference found

Latest-data paired comparison on generation `capture-1792521489-11910-293b919a` at
120×36 (read-only: Home `b`, `v`; LOAM Reports → Balances / Accounting). LOAM's Equity
section contained the opening-balance Equity coordinate; Bakhlo's showed
`(no supported rows)` with a zero subtotal. Cause: `Daily_overlays.role_balance_items`
enumerated `approved-loci` × every Measure, while LOAM's Role Balance
(`Loam/Review/RoleBalanceReview.lean`) represents the union of the current correction
frontier's coordinates and the zero-origin, opening, anchor and presence families. A
coordinate used in entries but absent from `LocusAdmission` was dropped, and admitted
coordinates without any evidence were listed.

### Change

- `represented_coordinates` builds that union from `Current_quantity_query` (frontier
  Events' Effects, zero-origins, openings, assertion groups, presence) in
  `Effect_coordinate.compare` order; Measures without a represented coordinate get no
  section. Section structure, completeness flags and amounts are unchanged.
- Cost measured with `./tools/startup-probe 109500` (synthetic): the first version took
  46.5 ms (median of 21); Hashtbl de-duplication 21.3 ms. The result is cached for the
  last book image (physical equality; a publication replaces the image), so only the first
  Accounting paint after a change pays it.
- `tui/scenarios/balances_integration_checks.ml`: the mode-switch check now uses a
  coordinate present in both views (`wallet / jpy`); a new check requires the zero-origin
  coordinate and excludes an admitted Locus without evidence and a Measure without evidence
  (`accounting-represents-evidence-coordinates-not-admissions`).

### Evidence

- `./tools/check`, `./tools/tui --self-check` (39 PASS), `git diff --check` passed.
- After the change on the same generation at 120×36: per-role row values (Asset 6,
  Liability 3, Equity 1), role subtotals and jpy Known Net Worth equal LOAM's (compared by
  script in ignored scratch; values not recorded). Row order now follows tokens as in
  LOAM. 80×24 opened Accounting; only its first page was read (Equity is below the fold
  there). Household/config SHA-256 unchanged, comparison book unchanged, AI tmux sessions
  closed, `clean-copies` passed.
- Remaining presentation difference: LOAM's Accounting also shows an Answerability Map,
  next-evidence targets and an all-current-balance support list; Bakhlo does not.

### Limits

Other Measures than jpy, physical terminal/IME, human acceptance and P7 were **not
executed**.
## Balances Current list detail and key guide (2026-10-21)

### Scope and source reference

- Worker branch `omp/balances-ui24`, base `710129f`. Product edits are confined to
  `tui/screens/balances/balances_screen.ml`; regression edits to its owner test and
  `tui/scenarios/balances_integration_checks.ml`. No shared Shell/API/Core/kit,
  exported interface, dependency declaration or storage format changed.
- Read-only reference: LOAM `Loam/Tui/Balances.lean` quantity/detail lines 61–94,
  footer/geometry 117–155, table/panels 180–238. LOAM was neither built nor run;
  this is source alignment plus synthetic Bakhlo verification, not paired parity.
- Current list, detail and Print Preview use stable IDs and exact Measure-scaled
  **Amount**, without a positive adjustment `+`. The initial raw-Quanta version
  described below was superseded by the review correction in this section.
  Detail order is Locus, Measure, Amount with Measure, State, any unknown
  explanation, neutral-coordinate note. Zero, presence-only and unsupported stay distinct.
- Reused `Ui_panel.frame_rows ~inset:0` for Current markers, muted detail rows,
  one-cell indent and position/overflow indicators. One owned layout serves
  painting, list paging and detail scrolling: 80×24 uses a 10-row list, spacer and
  8-row detail; 120×36 splits; 48×14 and 32×9 switch to focused detail when needed.
  The Screen's supplied content height, including warning reductions, is used.

### Intentional differences and unchanged boundaries

- Review decision (2026-10-21): retain exact Measure scaling as a safer difference
  from LOAM's raw integer Quanta. `12,345 eur` for 123.45 EUR invites a 100×
  misreading; show `123.45 eur` and label the column/detail **Amount** instead.
  Reuse `Daily_overlays.format_money` for list, detail, width calculation and
  Print; do not rescale the stored quantity or the Observe intent. Scale-zero JPY
  stays `74,500 jpy`, and no positive `+` is added. The local raw formatter is removed.
- Compact rows preserve the Measure before clipping a long Locus. If the whole
  Measure cannot fit, the row shows a detail cue instead of digits that could be
  mistaken for another currency. Long Measures use compact form rather than a
  clipped currency column. Owner regressions cover both overflow cases.
- Existing `w` Measure, `v` Accounting, `c` configuration, `o` Observe and Space
  Commands remain connected; wide/medium key guides include them (abbreviated at
  80 columns). LOAM's navigation/page/print guides use bracketed keys. Tiny guides
  retain navigation, paging and print; other actions remain available.
- Accounting still uses the existing role-based, scaled Amount presentation.
  Its coordinate-preserving mode switch and paging are covered by synthetic
  scenarios; full LOAM Accounting acceptance is not claimed.
- Shell Standard chrome still owns the Bakhlo header, feedback and last row.
  Matching LOAM's complete outer canvas would require the integration owner's
  shared layout decision; no shared file was changed. Print remains an in-screen
  preview, not consented terminal output.
- Picker Review/Save, stale/blocked/uncertain refusal, unknown Observe amounts,
  separate Measures and print line/byte limits were not weakened.

### Initial synthetic evidence (before the scaled Amount correction)

- `rtk err ./tools/bootstrap`: passed; created only the worker's isolated locked
  Core environment.
- `rtk test ./tools/check`: **PASS** (Core build/tests and architecture checks).
  Its privacy-scan step, and a separate `./tools/privacy-scan` after the doc edits,
  reported **not executed** because this worktree has no private household copy
  under `scratch/`. No real-data copy was obtained to enable that scan.
- `rtk git diff --check`: **PASS**.
- `rtk test ./tools/tui --self-check`: attempted, exit **2**:
  `Existing isolated Bonsai environment unavailable; nothing installed.`
  Native build and native suites were **not executed**.
- For reachable coverage without installing TUI dependencies, copied the tracked
  source directories and public synthetic fixture into a disposable ignored
  workspace. Used the already-installed standard OCaml 5.4.1 libraries; compiled
  the existing bootstrap-installed Parsexp sources locally because the global
  switch lacks that library. No project dependency was added. `OCAMLPARAM` selected
  the 5.2 keyword set so existing identifiers named `effect` parse unchanged.
- `env OCAMLPARAM=_,keywords=5.2 rtk test opam exec -- dune test --root
  scratch/balances-ui24-pure --profile release --force tui/screens/balances/test`:
  **PASS**. Regressions cover raw scale-2 EUR list/Print, unchanged raw Observe
  intent, exact zero versus unknown/presence-only, 100-digit negative detail,
  nonnumeric overflow cues, currency preservation, detail field order, page
  capacities and selection/scroll retention across resize and return.
- A disposable OCaml runner called `Scenarios.run` and the actual
  `Shell_input`/`Shell_view` path using synthetic files, with Uucp cell widths.
  `env OCAMLPARAM=_,keywords=5.2 rtk test opam exec -- dune exec --root
  scratch/balances-ui24-pure --profile release smoke/balances_smoke.exe --
  "$PWD/scratch/balances-ui24-pure"` passed. Balances display/paging, picker
  Review/cancel/save/cold, multi-Measure Observe and refusal scenarios passed.
- Directly ran the compiled disposable runner against another fresh synthetic
  directory and observed the Shell-rendered surfaces at **80×24, 120×36,
  48×14 and 32×9**. Keys: select next, `i` detail, End, Esc, `p`, Esc. Raw Quanta
  and separate Measures, inactive selection, unknown detail/scroll indicators,
  compact layout and Print cancellation were visible; book bytes were unchanged.
  This is renderer/controller smoke, **not a native terminal/PTY run**.

### Initial-pass limits and integration note

- A broader standard-OCaml check attempt also exposed existing fatal warning 8
  in `tui/shell/test/record_session_checks.ml:211–213,226–228`: matches omit
  `Enable_unresolved _`. Those shared tests were not edited or warnings disabled;
  the successful standalone runner excludes `Shell_checks.run`. This is separate
  from the missing native environment.
- Latest-data paired comparison, `./tools/compare`, `./ui`, physical terminal/IME,
  human acceptance, P7/power-loss qualification, push and matching-SHA CI were
  **not executed**. No household/LOAM data or other worktree was accessed for runs.
- Disposable workspace/runner files are not part of the deliverable.
- Read-only review of the owned source found no actionable correctness defects;
  it did not independently run checks.

### Scaled Amount safety correction (2026-10-21)

- Continued from Claude's rebased `89f99bd` on `dc62a1f`; did not rebase again.
  The merged Accounting behavior and tests were retained.
- Replaced the local raw-integer formatter with existing
  `Daily_overlays.format_money`, including the table's width calculation.
  Current column/detail labels are **Amount**; list, detail and Print show
  `123.45 eur` for 12345 quanta, without a positive `+`. IDs, field order,
  geometry, overflow cues, unknown states, footer and publication gates are unchanged.
- `env OCAMLPARAM=_,keywords=5.2 rtk test opam exec -- dune test --root
  scratch/balances-scaled-review --profile release --force
  tui/screens/balances/test`: **PASS**. EUR list/detail/Print require the scaled
  form and reject the raw form. Decimal edge fixtures prove `0.01`, `-0.01` and
  exact `0.00`; Observe still returns the original 12345 integer quanta.
  Scale-zero JPY, huge values, unknown/presence-only, overflow and geometry
  regressions remain green.
- This uses the same disposable standard-OCaml workspace method as the initial
  pass, with existing installed dependencies only; no dependency was added.
- Native `./tools/tui --self-check`: **not executed** in this correction pass.
  The worktree still lacks the required isolated Bonsai environment; the prior
  prerequisite refusal was not rerun. Native qualification remains with the
  integration owner. Latest-data comparison, physical terminal/IME and P7 were
  **not executed**; no household/LOAM data was accessed and nothing was pushed.
- Built and ran a disposable OCaml smoke runner with `Scenarios.run` followed by
  the actual Balances `Screen.handle`/`Screen.view` and Print paths:
  `env OCAMLPARAM=_,keywords=5.2 rtk err opam exec -- dune build --root
  scratch/balances-scaled-review --profile release smoke/scaled_smoke.exe`,
  then `scratch/balances-scaled-review/_build/default/smoke/scaled_smoke.exe
  "$PWD/scratch/balances-scaled-review"`: **PASS**. Observed Amount headers,
  `123.45 eur`, `74,500 jpy` and matching Print content at 80×24, 120×36,
  48×14 and 32×9; Observe retained 12345 quanta. The merged Accounting,
  Balances paging/picker/Observe and other scenario checks passed. This is
  synthetic renderer/controller evidence, not native terminal acceptance.
- `rtk git diff --check`: **PASS**.
- `rtk test ./tools/check`: **PASS** (Core build/tests and architecture checks).
  `./tools/privacy-scan` reported **not executed** because the synthetic-only
  worktree has no private household reference copy; none was obtained.

## Balances UI-24 integration and latest-data comparison (2026-10-21)

- Integrated `omp/balances-ui24` (`68edaf5`, `89f99bd`, `a83bfc4`) on top of `dc62a1f`;
  the scenario conflict with the Accounting change kept both checks. Reviewer request
  applied by the worker: Measure-scaled exact Amount instead of LOAM's raw Quanta for
  Measures with a scale (intentional, to prevent misreading `12,345 eur` for 123.45 EUR).
- `tools/ci_tui_pty.py` expected the old `Balances / Current` title and `+1,000 jpy`; it
  now waits for `Balances [active]` and `1,000`. Local native PTY matrix passed (120×36,
  80×24, 48×14, 32×9 and the narrow Record Preview refusal).
- On the main checkout: `./tools/check`, `./tools/privacy-scan --all` (no match),
  `./tools/tui --self-check` (39 PASS) and `git diff --check` passed.
- Latest-data paired comparison on generation `capture-1792523574-57680-293b919a`,
  read-only (Home `b`; LOAM Reports → Balances / Current) at 120×36 and 80×24: the list
  rows (Locus ID, amount, Measure, state) are equal to LOAM's by script, and the selected
  detail has the same items and order. Remaining visible differences: `Amount` vs
  `Quanta` heading, Shell header line, extra Bakhlo keys in the guide, and at 80×24 the
  list frame is one row taller. Household/config SHA-256 unchanged, comparison book
  unchanged, AI tmux sessions closed, `clean-copies` passed.
- Accounting commit `dc62a1f`: matching-SHA
  [Core CI 39478791029](https://github.com/shumoku88-bit/bakhlo/actions/runs/39478791029)
  and [Bonsai TUI CI 39478790974](https://github.com/shumoku88-bit/bakhlo/actions/runs/39478790974)
  both succeeded.
- Physical terminal/IME, human acceptance and P7 were **not executed**.

## Scheduled replenishment integration and latest-data comparison (2026-10-21)

- Integrated `omp/scheduled-replenish` (`1044248`, `aa87144`, `da48b67`, rebased on
  `cc8a06d`). The only shared edit is the authorized `Gen.create` call in
  `tui/shell/shell_record_actions.ml`, which passes `F.today ()` only for monitored `e`.
- On the main checkout: `./tools/check`, `./tools/privacy-scan --all` (no match),
  `./tools/tui --self-check` (39 PASS), `git diff --check` and the local native PTY matrix
  passed.
- Latest-data paired comparison on generation `capture-1792524331-63399-293b919a` at
  120×36, read-only: Series Calendar first monitored plan, `e`, Next 3 occurrences.
  - Equal: source occurrence and date, known-through date, pattern, the four choices,
    and the first generated due date.
  - Different: LOAM continues into the ordinary Scheduled edit form for each occurrence and
    a per-occurrence Preview (Publish focused); Bakhlo shows one Preview of all three
    exact copies (Cancel focused). LOAM shows `Only reviewed explicit dates will be
    created.` on the choice screen; Bakhlo shows it in its Preview. LOAM Esc from its
    Preview cancels the whole generation; Bakhlo returns to the choices.
  - Nothing was published in either app: Bakhlo book SHA-256 and household/config SHA-256
    unchanged, no file in LOAM's copy newer than the capture. AI tmux sessions closed,
    `clean-copies` passed.
- `cc8a06d`: matching-SHA
  [Core CI 39482494062](https://github.com/shumoku88-bit/bakhlo/actions/runs/39482494062)
  and [Bonsai TUI CI 39482494087](https://github.com/shumoku88-bit/bakhlo/actions/runs/39482494087)
  both succeeded.
- 80×24, custom date, missing-month-day resolution against LOAM, physical terminal/IME and
  P7 were **not executed**.

## Accounting evidence details as in LOAM (2026-10-21)

Taken over from the stopped `omp/accounting-sections` worker (its model hit a usage
limit before any code; its one uncommitted ledger line in that worktree was left as is).

- `Daily_overlays.role_balance_items` now follows LOAM `Tui/RoleBalances.lean` and
  `Review/RoleBalanceAnswerability.lean`: `Current Balances`; per Measure with a stock-role
  or unresolved coordinate, Asset / Liability / Equity sections of exact rows only, Balance
  Sheet support, the known-present / unsupported stock lists, unresolved roles, Known and
  Qualified Net Worth as two lines with LOAM's notes; then `Evidence details`, the
  Answerability Map (exact support, role coverage, Balance Sheet / Net Worth
  ANSWERABLE/BLOCKED with counts, all current balances, flow-role gaps), next evidence
  targets and notes, and `All current balance support`. The per-Measure Income / Expense
  sections were removed; flow rows appear in the support list as in LOAM. Each represented
  coordinate is exactly one of exact-with-role, exact-unresolved, known-present or
  unsupported; nothing is coerced to zero. Amounts keep Bakhlo's Measure-scaled format.
- The block moved below `format_money`, which it uses. Net Worth's row renders only the
  known subtotal; the qualified line is its own row.
- Checks: `balances_integration_checks.ml` requires the Answerability, next-evidence,
  qualified Net Worth and support lines for a book with two exact unclassified coordinates;
  `publication_integration_checks.ml` finds `Expense` among all Accounting items instead
  of on the first 120×30 page.
- `./tools/check`, `./tools/tui --self-check` (39 PASS) and `git diff --check` passed.
- Latest-data paired comparison on generation `capture-1792541247-79518-293b919a` at
  120×36, read-only, paging through both views (script comparison in ignored scratch, no
  values recorded): Answerability lines, Balance Sheet / Net Worth status lines,
  Qualified Net Worth, exact quantity / role classification / Balance Sheet support lines,
  the ten supported rows and the 31 classified unsupported coordinates equal LOAM's; every
  section is present in both. Difference: Bakhlo's list pane sits beside its detail pane,
  so the longest explanatory lines are clipped with `…` (their visible prefix equals
  LOAM's). Household/config SHA-256 and the comparison book unchanged, AI tmux sessions
  closed, `clean-copies` passed. 80×24, physical terminal/IME and P7 were **not executed**.
- `4eafbb4`: matching-SHA
  [Core CI 39483903041](https://github.com/shumoku88-bit/bakhlo/actions/runs/39483903041)
  and [Bonsai TUI CI 39483903048](https://github.com/shumoku88-bit/bakhlo/actions/runs/39483903048)
  both succeeded.

## Scheduled List and Months monitoring keys (2026-10-21)

Taken over from the stopped `omp/scheduled-monitor-add` worker (no code had been written).

- `tui/screens/scheduled/scheduled_screen.ml`, following LOAM `ScheduledWorkspace.lean` /
  `ScheduledWorkspaceSession.lean`: in List and Months the selected plan accepts `p` / `m`
  (choose expected pace and save the monitoring rule), `s` (pace undecided) and `e`
  (extend). `e` on a monitored plan opens generation on its cadence, refuses an undecided or
  unsupported cadence, and on an unmonitored plan opens the pace chooser first; after that
  save the generation editor opens from the same plan. Esc there reports `Extend cancelled;
  no recurring pattern was selected.` and saves nothing. The Loci pane refuses these keys.
  Edit moved from `e` to `r` (LOAM's replace key; Ctrl-e kept). Guides updated.
- Only `scheduled-coverage.tsv` is written, through the existing checked whole-image save;
  the book is never written by these keys.
- Regressions (`scheduled_integration_checks.ml`, synthetic): List `p` opens and Esc keeps
  the config; `e` on an unmonitored plan asks first, Esc cancels, Monthly saves the rule
  and opens generation from that plan with a 1-month cadence; `s` makes it undecided and
  `e` then refuses; Loci pane refusal; Months `m` opens the chooser; book bytes unchanged.
  With the screen change reverted the suite fails at `list-p-opens-expected-pace`. Two
  older checks that edited with `e` now use `r`.
- `./tools/check`, `./tools/tui --self-check` (39 PASS) and `git diff --check` passed.
- Latest-data paired comparison on generation `capture-1792541924-84250-293b919a` at
  120×36, read-only: both List views show 33 plans; `p` opens the same chooser (same
  selected plan, choices, notes, keys; Bakhlo adds its subtitle line); Esc gives the same
  `Plan monitoring unchanged.`; `e` on the first (monitored) plan opens the same Extend Plan
  source, known-through date, pattern and choices; Esc returned both to the List. No save in
  either app: household/config and comparison book SHA-256 unchanged, no file in LOAM's copy
  modified, AI tmux sessions closed, `clean-copies` passed.
- Not done: LOAM's expected-pace choice right after creating a plan (needs a Shell hook
  after publication); `e` on an unmonitored plan against LOAM with real data; 80×24;
  physical terminal/IME; P7.
- Pushed `d1c906e`; matching-SHA
  [Core CI 39520957571](https://github.com/shumoku88-bit/bakhlo/actions/runs/39520957571)
  and [Bonsai TUI CI 39520957237](https://github.com/shumoku88-bit/bakhlo/actions/runs/39520957237)
  both succeeded.
- `482a9c9`: matching-SHA
  [Core CI 39519824236](https://github.com/shumoku88-bit/bakhlo/actions/runs/39519824236)
  and [Bonsai TUI CI 39519824159](https://github.com/shumoku88-bit/bakhlo/actions/runs/39519824159)
  both succeeded.

## Liquidity conditional selected-balance outlook (2026-10-21)

- Base: `482a9c9`, implementation `514ce2c`, worker branch `omp/liquidity`.
  Only the Reports owner/tests,
  additive Commands entry and minimal route/registry wiring changed; no Core,
  shared kit, Scheduled or Balances behavior changed. LOAM sources were read only:
  `Loam/Review/ConditionalBalancePathReview.lean` and the Liquidity portions of
  `Loam/Tui/ReportsModel.lean` / `ReportsView.lean`. No LOAM build or source copy.
- Commands → Reports and analysis → Liquidity opens a read-only report.
  `Forecast path: UNKNOWN` and `Known low-water mark: UNKNOWN` remain unconditional
  statements before and after Run. Known Scheduled items are not all future flows;
  no retained complete-future evidence is invented.
- The first entry displays the selected day's Gregorian month end. Tab/Shift-Tab
  switches date/Run; Enter on the date only advances focus, Enter on Run accepts the
  displayed assumption. Backspace edits; `m` resets to the current selected-day
  month end. The complete-through date is inclusive, ephemeral and not evidence.
  Edit/reset/reload/book change invalidates the prior answer; drafts survive re-entry.
  Space opens Commands; q/Esc returns Home. There is no save/publication request.
- `balance-view.tsv` must be explicit, nonempty, duplicate-free and single-Measure.
  Every selected coordinate must have an existing Exact current quantity;
  Known-present/amount-unknown and unsupported remain distinct refusals, never zero
  or a partial sum. The selection, not the Shell's ambient Measure, chooses the unit.
  Only existing `Daily_book.open_plans` are used. Nonzero selected-net overdue plans
  refuse the whole query; foreign-Measure and zero selected-net plans are irrelevant
  before the overdue check. Due-today and horizon-day changes are included.
- Conditional inflows/outflows are netted by day with exact `Z.t` arithmetic.
  Low-water includes the current baseline and every day boundary, not intraday
  ordering. At most 12 change rows are displayed with an explicit omitted count;
  final balance and low-water still include every point.
- Intentional presentation/safety differences from LOAM: amounts use the existing
  exact Measure-scaled formatter rather than raw integer Quanta (synthetic
  `12345` at EUR scale 2 means `123.45 eur`); duplicate coordinates refuse rather
  than being counted twice. Two UNKNOWN rows remain visible while the remainder
  scrolls. Explanatory limitations precede the path, leaving exact totals reachable
  with End. Shared Shell header/feedback/footer geometry is unchanged.
- Synthetic owner regressions cover exact/unknown/zero, mixed Measures, duplicates,
  canonical dates and due-today/inclusive horizons, overdue selected money versus
  zero-net internal transfers and unrelated currencies, paid/cancelled exclusion,
  same-day cross-plan zero, negative/huge scaled amounts, and a hidden 14th point
  that changes both totals after the 12-row display limit. Screen checks cover
  explicit Run, invalidation, preserved drafts, leap-year month end, no-write
  requests, missing/malformed/empty selection, scrolling and four geometries,
  including focused-date bounds with one additional feedback row.
- Executed:
  - `rtk test ./tools/check` — **PASS** (Core build/tests).
  - `env OCAMLPARAM=_,keywords=5.2 rtk test opam exec -- dune test --root scratch/liquidity-owner.mPrhDX --profile release --force tui/screens/reports/test`
    — **PASS**, including Stock–Flow and Liquidity. The first attempt refused an
    invalid synthetic v1 fixture (`unsupported-field`); corrected it to canonical
    v3 with entry exchange and plan cancellation fields, without changing the parser.
  - `env OCAMLPARAM=_,keywords=5.2 rtk err opam exec -- dune build --root scratch/liquidity-owner.mPrhDX --profile release smoke/liquidity_smoke.exe`
    followed by `rtk test scratch/liquidity-owner.mPrhDX/_build/default/smoke/liquidity_smoke.exe scratch/liquidity-owner.mPrhDX`
    — **PASS**. The disposable runner
    executed the full `Scenarios.run`, including real Commands-menu navigation to
    Liquidity and an exact conditional answer over a synthetic book.
    A subsequent actual-Shell rendering probe exercised 120×36, 80×24, 48×14 and
    32×9, End scrolling, the physical date-caret cell at each size, and invalid-date
    refusal without stale amounts. Synthetic book/config bytes were unchanged.
  - `rtk test ./tools/tui --self-check` — **not executed**: exit 2,
    `Existing isolated Bonsai environment unavailable; nothing installed.`
  - `./tools/privacy-scan --all` — **not executed**: no private household reference
    copy exists under scratch; none was created or accessed to enable this scan.
  - `rtk git diff --check` and `rtk git diff --cached --check` — **PASS**.
- Read-only pit review found no contract-violating financial or lifecycle issue;
  runtime verification above was performed separately by the integration worker.
- The disposable build used existing installed packages and Parsexp sources under
  a source-only Dune workspace, OCaml 5.4 with 5.2 keywords, without the native
  Bonsai application. This is pure-owner/Shell evidence, not native TUI acceptance;
  temporary sources, binaries and synthetic captures are removed after verification.
  `tools/ci_tui_pty.py` is unchanged; no Balances text or existing menu entry moved.
- Latest-data paired comparison, physical-terminal/IME acceptance and P7/power-loss
  qualification were **not executed**. Neither `./tools/compare` nor `./ui` ran;
  no household/LOAM data was accessed. Native self-check and latest-data comparison
  remain for the main-checkout review; this does not certify complete future coverage.

## Liquidity integration and latest-data comparison (2026-10-21)

- Integrated `omp/liquidity` (`af2943b`, `caf742e`, rebased on `7fbebd4`; the
  VERIFICATION append conflict kept both sections). Shared edits are the additive
  `Liquidity` route / command / registry / title wiring authorized for this slice.
- The worker could not build `tui/screens/reports/test` in its worktree; on main the owner
  test failed to compile because it called `Base`, which its test stanza does not link.
  `4976fa1` replaces those calls with a local substring helper (no new library).
- On the main checkout: `./tools/check`, `./tools/privacy-scan --all` (no match),
  `./tools/tui --self-check` (40 PASS, now including the Liquidity owner checks),
  `git diff --check` and the local native PTY matrix passed.
- Latest-data paired comparison on generation `capture-1792545422-2755-293b919a` at
  120×36, read-only (Commands → Reports and analysis → Liquidity, then run the conditional
  query with the default month-end date): both show `Forecast path: UNKNOWN`,
  `Known low-water mark: UNKNOWN`, the same default assumed-complete-through date, and both
  refuse the run for the same overdue selected Scheduled occurrence. Differences: wording
  of the explanatory lines; Bakhlo repeats the refusal in the body and the feedback line,
  and the feedback wraps mid-word. Household/config and comparison book SHA-256 unchanged,
  no file in LOAM's copy modified, AI tmux sessions closed, `clean-copies` passed.
- A successful conditional path on real data (no overdue selected plan), 80×24, physical
  terminal/IME and P7 were **not executed**.

## Trend / Locus comparison integration and latest-data comparison (2026-10-21)

- Integrated `omp/trend-locus` (`4675805`, rebased on `40754aa`). The worker hit the Codex
  limit mid-implementation and finished on the fallback parent model `step-5-preview`
  (deepseek subagents). Rebase conflicts were the two additive report wirings (Liquidity /
  Trend) in route, command, workspace, title and registry, kept both. The worker had pinned
  the existing `reports_checks` stanza to `(modules reports_checks stock_flow_checks)` for
  the arch rule; that would have dropped `liquidity_checks`, so the stanza now lists it and
  keeps `bakhlo_tui_protocol`. The UI-25 ledger row merges both sides.
- Review: exact recorded Effect sums per Locus × Measure, refunds keep their own sign,
  missing/ambiguous boundary configuration is unavailable (never an inferred zero or
  month). Cycle / Month points show LOAM's integer per-day average, labelled
  `floor average … /day`; Day points are exact.
- On the main checkout: `./tools/check`, `./tools/privacy-scan --all` (no match),
  `./tools/tui --self-check` (43 PASS), `git diff --check` and the local native PTY matrix
  passed.
- Latest-data paired comparison on generation `capture-1792548895-22617-293b919a` at
  120×36, read-only: the same cycle source and periods; with coffee and food added as
  Bakhlo series 4 and 5, their per-day values equal LOAM's for the current partial cycle and
  the three previous cycles (script comparison in ignored scratch; values not recorded).
  Differences: LOAM's default series are three household Loci hard-coded in LOAM's source;
  Bakhlo takes the first catalog Loci (it cannot carry household tokens), so its default
  chart can be all zero. LOAM draws interpolated braille lines with a period axis and mouse
  scrubbing; Bakhlo draws dotted lines with markers, no pointer scrub, and a different
  header. Household/config and comparison book SHA-256 unchanged, no file in LOAM's copy
  modified, AI tmux sessions closed, `clean-copies` passed.
- `40754aa`: matching-SHA
  [Core CI 39526740489](https://github.com/shumoku88-bit/bakhlo/actions/runs/39526740489)
  and [Bonsai TUI CI 39526740465](https://github.com/shumoku88-bit/bakhlo/actions/runs/39526740465)
  both succeeded.
- Month / Day grains against LOAM, 80×24, physical terminal/IME and P7 were **not executed**.


## Multicurrency Spend (2026-10-21)

- Base: `40754aa`, worker branch `omp/multicurrency`. Only the Reports owner/tests,
  additive Commands entry and minimal route/registry wiring changed; no Core,
  shared kit, Scheduled or Balances behavior changed. LOAM sources were read only:
  `Loam/Review/MultimeasureSpendReview.lean` and the Liquidity/Multicurrency portions of
  `Loam/Tui/ReportsView.lean`, `ReportsModel.lean`, `ReportWindow.lean`. No LOAM build
  or source copy.
- Commands → Reports and analysis → Multicurrency Spend opens a read-only Actual lens.
  The explicit half-open window `[Start, End)` is seeded from the selected day's calendar
  month; Start/End are editable and Run queries only on explicit Enter. `m` restores the
  selected month; `[`/`]` cycle Calendar Month and named `boundary-presets.tsv` sources;
  arrows shift Calendar Month only. Any edit makes the source explicitly Custom.
- Four families stay separate and are never converted or merged: ordinary accounting
  Expense per Measure (non-exchange entries), OriginalAmount presented Expense (counted
  once per entry with any positive Expense Effect, in the original Measure),
  exchange-associated Expense (only explicitly Expense-role legs, so fees are not
  purchase spend), and exact Exchange occurrences (selected source/destination keys plus
  extra Effects in recorded order). No FX rate, valuation or home currency is inferred.
- Missing AccountingRole evidence stays visible: every nonzero role-absent Effect is an
  unresolved witness, and classified figures are explicitly qualified as not a complete
  spending total. Every original observation is accounted for exactly once — counted,
  unresolved (missing roles), or non-counted with a reason (exchange event / no positive
  Expense). No observation is silently dropped and no sign is inferred for it.
- Lifecycle: an edit, source change, `m`, reload or book change clears the cached answer;
  a refused Run never leaves stale numbers; date drafts survive errors and re-entry.
  Named-source coordinates relabel as Custom when preset membership changes. There is no
  save/publication request; Space opens Commands and q/Esc returns Home.
- Intentional differences from LOAM: original observations that LOAM drops are retained
  as explicit non-counted witnesses; all unresolved rows are reachable under scroll
  (LOAM truncates to six); amounts use the existing exact Measure-scaled formatter
  (synthetic `5000` at EUR scale 2 means `50.00 eur`, not raw quanta); net-zero Measure
  rows that were touched are retained. Existing `boundary-presets.tsv` parsers are
  private in sibling modules, so this owner keeps a local parser of the same format
  rather than widening a shared API.
- Executed:
  - `rtk test ./tools/check` — **PASS** (Core build/tests).
  - `env OCAMLPARAM=_,keywords=5.2 rtk test opam exec -- dune test --root _build/daily-bonsai --profile release --force tui/screens/reports/test`
    — **PASS**, including Stock–Flow, Liquidity and the new Multicurrency Spend suite.
    The isolated workspace reproduces `tools/build-bonsai-tui`'s generated roots with
    `(implicit_transitive_deps false)`, so undeclared transitive library use is a
    compile error; the new code uses only the libraries already listed in the existing
    stanzas (no `Base` in the reports test stanza).
  - A disposable Shell runner driven through real Commands navigation to
    Multicurrency Spend, an explicit Run over a synthetic two-Measure book, and the
    actual rendered screen at 120×36, 80×24, 48×14 and 32×9 — **PASS**. Rendered output
    showed `50.00 eur` and `1,000 jpy` as separate Measures, the no-conversion
    disclaimer, scroll cues, and End reaching the final notes. Esc returned Home and the
    synthetic book and `accounting-roles.tsv` bytes were unchanged.
  - `rtk git diff --check` and `rtk git diff --cached --check` — **PASS**.
  - `rtk test ./tools/tui --self-check` — **not executed**: exit 2,
    `Existing isolated Bonsai environment unavailable; nothing installed.`
  - `./tools/opam exec -- dune build @tools/arch/runtest` — **not executed**:
    `Library "parsexp" not found`; verified identical on pristine `origin/main`, so it
    is an environment limitation, not this change.
- Two pre-existing scenario failures (`panel-bounded-render`,
  `flow-screen-shows-gross-column`) abort `Scenarios.run` in this isolated build. Both
  were reproduced on a pristine `origin/main` workspace built the same way, so they are
  not caused by this change; the new integration flow was therefore exercised directly.
- Latest-data paired comparison, physical-terminal/IME acceptance and P7/power-loss
  qualification were **not executed**. Neither `./tools/compare` nor `./ui` ran;
  no household/LOAM data was accessed. This does not certify multicurrency parity.

## Multicurrency Spend integration and latest-data comparison (2026-10-21)

- Integrated `omp/multicurrency` (`fd7a822`, rebased on `a12ffb2`; worker finished on the
  `step-5-preview` fallback parent). Conflicts were the third additive report wiring
  (route, command, workspace, title, registry), all kept; the explicit `reports_checks`
  module list now includes `multicurrency_spend_checks` (otherwise it would not compile into
  that test). VERIFICATION sections kept whole; the UI-25 ledger row was rewritten by hand
  to merge all three reports.
- On the main checkout: `./tools/check`, `./tools/privacy-scan --all` (no match),
  `./tools/tui --self-check` (44 PASS), `git diff --check` and the local native PTY matrix
  passed.
- Latest-data paired comparison on generation `capture-1792549505-29835-293b919a` at
  120×36, read-only, default Calendar Month window run in both: the same window, ordinary
  Expense total, the same four unresolved ordinary Effects (date, Locus, signed amount,
  record) and the same empty OriginalAmount / Exchange sections. Only difference in values:
  Bakhlo groups thousands. Explanatory lines and key guide wording differ. Household/config
  and comparison book SHA-256 unchanged, no file in LOAM's copy modified, AI tmux sessions
  closed, `clean-copies` passed.
- `a12ffb2`: matching-SHA
  [Core CI 39532391852](https://github.com/shumoku88-bit/bakhlo/actions/runs/39532391852)
  and [Bonsai TUI CI 39532391901](https://github.com/shumoku88-bit/bakhlo/actions/runs/39532391901)
  both succeeded.
- A window with OriginalAmount or Exchange evidence, 80×24, physical terminal/IME and P7
  were **not executed**.

## Scheduled expected pace after creation (2026-10-21)

- LOAM reference (read-only): `ScheduledCreationSession.finishCreated` and
  `ScheduledCoverageSetupSession.runAfterCreation`. Ordinary creation from the Scheduled
  workspace or Selected Day offers the published plan's expected pace; the continuation's
  next Scheduled (`runWithScheduledId`) does not.
- Bakhlo: the creation editor carries `offer_pace` (true for an ordinary creation, false for
  a continuation Add) on `Create_plan`. After a confirmed publication the Shell re-reads the
  plan from the reloaded book and opens the Scheduled owner's chooser as a modal over the
  current route, so the route, drill and Selected Day are untouched and leaving returns
  there. Choices: this occurrence only (default, nothing saved), the five cadences, explicit
  undecided (`0`). Esc saves nothing. No future Scheduled is created. A missing identity or
  an unusable signed-Locus shape refuses instead of guessing.
- Found and fixed while testing: the Scheduled creation editor consumed `j`/`k` as
  candidate moves, so a Locus such as `bank` could not be typed. Only arrows move
  candidates now.
- Regressions in `tui/scenarios/scheduled_integration_checks.ml` (`created-pace-*`): offer
  after ordinary creation, Esc keeps config and returns to List, cadence and undecided save
  without another plan, Commands creation stays over and returns to the starting route,
  selection visible/bounded at 32×9, 48×14, 80×24, 120×36. The existing continuation check
  still requires no modal after Add. Each new check failed with its fix removed (offer hook,
  `j`/`k`, chooser windowing).
- `./tools/check`, `./tools/tui --self-check` (44 PASS) and `git diff --check` passed.
- Synthetic native walkthrough (`examples/daily-book.sexp` copy in scratch): 80×24 create →
  chooser → Monthly saved `scheduled-coverage.tsv` and returned to List; 48×14 Esc left the
  coverage bytes unchanged and returned to List; 48×14 Up showed the selected last choice.
  Book `--check` passed afterwards.
- `a00acdf`: matching-SHA
  [Core CI 39547836045](https://github.com/shumoku88-bit/bakhlo/actions/runs/39547836045)
  and [Bonsai TUI CI 39547835944](https://github.com/shumoku88-bit/bakhlo/actions/runs/39547835944)
  both succeeded.
- Latest-data paired comparison (the flow writes), physical terminal/IME and P7 were
  **not executed**.

## LOAM import in the repository (2026-10-21)

- Migration policy (user decision, cutover diff ledger): one import on the cutover day;
  current state only; correction history, retired/replaced plans and budget stay in the
  LOAM record.
- `migrate/loam_import.ml(i)` replaces the private scratch converter. It builds a
  `Daily_book.payload` and admits it with the book's own `Daily_book.of_payload` (no second
  admission engine), then requires every coordinate's quantity and premise to equal LOAM's
  image. New: Merchant / Nonmerchant on the current terminal, root original amounts and
  exchange keys are carried (superseded-Event Merchant facts are not inherited);
  bounded-history support is part of the payload; settlement relations refuse;
  `attention` returns the household Attention section, which Bakhlo reads unchanged.
- `tools/compare` now links the library; the capture writes `attention.loam` beside the
  book (the app reads Attention from the book's directory). Its self-check requires the
  Attention copy and failed with the write removed.
- `test/loam_import_tests.ml` (synthetic): current-state entries with correction, merchant,
  original amount, exchange and reversal; completed / retired / replaced plans; bounded
  history; approved Loci; cold codec; Attention present / absent; refusal of a missing
  Measure scale and of settlement relations.
- Equivalence on real data: the old private converter and the new library produced
  byte-identical books on the three latest comparison generations.
- Latest-data refresh through the new path succeeded; read-only paired 120×36 Attention:
  both show two open items with the same due information (one dated, one without a due
  date). LOAM household/config bytes unchanged; AI sessions closed; `clean-copies` passed.
- `eaf8024`: matching-SHA
  [Core CI 39550727745](https://github.com/shumoku88-bit/bakhlo/actions/runs/39550727745)
  and [Bonsai TUI CI 39550727699](https://github.com/shumoku88-bit/bakhlo/actions/runs/39550727699)
  both succeeded.
- `./tools/check` and `./tools/tui --self-check` passed. The cutover-day procedure,
  physical terminal/IME and P7 were **not executed**.

## Cutover import command and rehearsal (2026-10-21)

- `./tools/import-loam LOAM_DIRECTORY NEW_BAKHLO_DIRECTORY` (`migrate/bin/import_loam.ml`)
  reads `household.loam` and `config/`, imports through `Loam_import`, and creates a new
  directory: `book.sexp`, `attention.loam`, `config/accounting-roles.tsv` from the household
  section, the other config files byte-exact (budget-only `purpose-catalog.tsv` /
  `cycle-funding.tsv`, the standalone roles file and lock files stay in LOAM) and
  `LOAM-RECORD.md` (import time, LOAM location and Git revision, what stays only in LOAM).
  It writes a `.partial-PID` directory with `O_EXCL` + `fsync`, reads the book back,
  re-snapshots LOAM and renames last; an existing destination, a destination inside LOAM, a
  changed source or any import refusal creates no destination. The wrapper reads the
  revision with `git rev-parse` and `git --no-optional-locks status` (no index write).
  Account/category role validation moved into `Loam_import.accounting_roles`, shared with
  `tools/compare`.
- `test/import_loam.t` (synthetic): files created, budget/lock/standalone-role files left
  out, household roles and Attention placed, LOAM directory unchanged, existing destination
  and missing role section refuse without creating anything.
- Rehearsal on real data into ignored scratch: import succeeded; `book.sexp`,
  `attention.loam` and the seven config files equal the comparison capture of the same
  generation. Read-only 120×36 against the LOAM copy of that generation: same number set on
  Daily Pace, same monitored plans/months and row count on the Series Calendar, Attention
  two open with the same due dates. Viewing changed no rehearsal file; LOAM household,
  config, `attention.loam`, `.git/index` and HEAD unchanged; `clean-copies` passed.
- `a891bc3`: matching-SHA
  [Core CI 39553668593](https://github.com/shumoku88-bit/bakhlo/actions/runs/39553668593)
  succeeded; the TUI workflow is path-filtered and did not run (no TUI or shared library
  path changed; the local self-check passed).
- `./tools/check` and `./tools/tui --self-check` passed. The real cutover, physical
  terminal/IME and P7 were **not executed**.

## Cutover (2026-10-21)

- User decision: cut over today; household under the `moko` directory. LOAM was closed and
  its data directory had no uncommitted change; the destination did not exist.
- `./tools/import-loam ../loam-data ../bakhlo-data` succeeded. LOAM household, config,
  `attention.loam`, `.git/index` and HEAD were unchanged afterwards.
- `book.sexp` equals the comparison capture of the same generation. On a copy of the new
  household, read-only 120×36 against the LOAM copy of that generation: identical number sets
  on Daily Pace, Balances and Scheduled; Attention the same open count and due dates (only
  today's date and LOAM's position counter differ in display). The new household's files
  were unchanged by the check; AI sessions closed; `clean-copies` passed.
- Not executed: systematic per-screen user acceptance, physical IME, P7 and power loss.

## Household launcher with automatic backup (2026-10-21)

- User decision: `bakhlo-data` is a Git repository pushed to the private GitHub repository
  `shumoku88-bit/bakhlo-data` (created with `gh repo create --private`; visibility checked
  PRIVATE). `tools/household` opens the book in the TUI and on exit commits any change and
  pushes; a failed push keeps the local commit and is retried on a later exit.
- Synthetic household with a local bare remote in scratch: no change commits nothing; a
  change is committed and pushed; an unreachable remote keeps the commit locally
  (`ahead 1`) and the next exit pushes it; a real tmux terminal run opened the TUI, `q`
  exited with status 0, and the change reached the remote.
- The real household was not opened by the AI.
