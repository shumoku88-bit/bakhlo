# Instructions for the next pit

`pit` means an AI coding assistant. Read README and `docs/HANDOFF.md` (current
state) first, then the nearest implementation/interface and the relevant parts of
`docs/SEMANTIC_CONTRACT.md`. Other docs are on-demand references, not a reading
list or a backlog. This file holds rules and user decisions only: put status in
HANDOFF or the ledgers and evidence in `docs/VERIFICATION.md`, never here.

## Principles (user decision: 2026-10-20)

- Bakhlo is in daily use since the 2026-10-21 cutover. Code may still change freely and
  obsolete paths are deleted, but a book or config format change needs an explicit,
  user-approved migration of `../bakhlo-data` (no silent rewrite on load).
- LOAM is a behavioral reference, not a source of bugs, unsafe behavior or poor UX
  to reproduce. Keep an intentional safer or more correct difference when justified;
  document and test the difference instead of silently calling it parity.
- Before adding a mechanism, check, document or safety layer, ask what can be removed
  instead. Do not grow a protocol, format or doc to work around an earlier choice.
- User decision (2026-10-27): Bakhlo should read like a program a woodworker made by
  hand with care. Fit parts by their types instead of glue helpers; name things for
  what the household means (not an earlier design); finish the parts nobody sees
  (tests, tools, file names); prefer removing to adding; one owner per rule.
- Measure before optimizing; state the result as numbers, not adjectives.
- Report outcomes faithfully: code connected, synthetic tests, latest-data paired
  comparison, human/IME acceptance and P7/power-loss are separate claims.

## Development loop (user decision: 2026-10-18)

- Single maintainer: commit/push small, reviewed, tested slices directly to `main`.
  No branch/PR for ordinary changes; isolate only large/risky/parallel experiments.
  Never force-push or overwrite/commit another worker's uncommitted edits.
- At the start of a pass, inspect remote HEAD, pending edits and `tasks/todo.md`.
  `docs/LOAM_UI_GAP_LEDGER.ja.md` is the only per-screen gap ledger;
  `docs/CUTOVER_DIFF_LEDGER.ja.md` is the user's summary for the five daily-use
  areas (Record, Scheduled, Loci, Balances, Daily Pace) — update its rows in the same
  slice when a difference is found, fixed or compared, linking details elsewhere.
- Choose one bounded slice, read its owner and dependencies, preserve existing
  features, add narrow regression checks, run `./tools/check` and
  `./tools/tui --self-check`, review the exact diff, update ledger/evidence, push.
  If something could not run, record **not executed**; never fabricate success,
  infer a missing balance or weaken Preview/save refusal.
- After pushing, inspect the CI run for the **matching commit SHA**
  (`core.yml`: Core and TUI build and tests, plus a Linux PTY smoke). Synthetic green ≠
  physical-terminal, IME, paired-parity or P7 acceptance. Investigate failures.
- Parallel AI work: agree file/function ownership first; shared Shell/API changes are
  serialized. Per-screen state/input/painting live in `tui/screens/<screen>`.

## Latest-data comparison (user decision: 2026-10-19)

- User decision (2026-10-25): LOAM reads the shared `book.txt` itself, so both UIs open
  copies of the same household `book.txt` (the LOAM import comparison is in Git up to
  `502d570`). `./tools/compare refresh` copies `../bakhlo-data/book.txt` and `config/`
  into a new generation under `scratch/comparison`, one copy per UI (read only; a
  household changed while copying is refused and the previous CURRENT stays). Use that
  one generation for before/after checks.
- Compare Bakhlo (`./ui`) and LOAM (`./ui loam`) on their copies from the same
  generation for changed screens and for Core changes affecting displayed answers, at
  the user's normal and a narrow geometry. Read-only flows only unless the user
  explicitly asks for writes; verify household/config bytes are unchanged afterwards.
- Then close only the AI's processes and run `./tools/compare clean-copies` (keeps the
  selected generation). Never fall back to originals or an old capture.
- Keep private inputs, captures and results in ignored scratch; record only build
  identity, freshness, dimensions, flows, non-private findings and limits. If copying
  or a binary is unavailable, record **latest-data paired comparison not executed**.
- This workflow authorizes no scheduler or automatic sync.

## Product

- Reproduce LOAM's user-facing non-budget functionality, appearance and interaction
  (recording/editing, plans, balances, Daily Pace, reports, hierarchical Commands).
  User decision (2026-10-22): no Calendar; the bonsai Home opens Actual, whose period
  windows (Cycle / Month / Year) are where periods are browsed and chosen.
  Budget allocation/transfer/consumption/routing and the Budget Window wait until
  actually needed — no speculative budget code. Fava and
  hledger export are out of scope (other output/diagnostics are not, without a
  separate decision). Internal structures need not match LOAM; observable results and
  safety behavior must. Cutover is a separate decision (`docs/CUTOVER_CHECKLIST.ja.md`).
- Today's spending guide is LOAM Home `d` Daily Pace. `docs/UI_DIRECTION.ja.md` owns UI
  policy: English first (Japanese undecided), Notty terminal (user decision 2026-10-21:
  Bonsai_term was replaced; Bonsai is explored outside Bakhlo), quiet colors, stable
  geometry, preserved drafts/selection, visible safety errors. Share UI mechanics only
  when current callers justify it (`tui/README.md`).
- Reports (user decision 2026-10-22): improve on LOAM rather than copy it, keeping
  what LOAM did well (Trend look, I&E summary with Scheduled split, period compare).
  Order reports by what the household's data shows matters; default to the configured
  cycle. A Locus with bounded history must still be reported (unknown only before its
  start), never refuse the whole report.
- Exact quantities, distinct currencies, unknown versus zero, real refunds and
  cancellations matter. Never guess facts, round amounts, trim identities or skip
  unsupported input. Preserve payment-plan links and stable IDs.
- Use observed household needs to order work, not to drop LOAM features from the
  parity inventory. Do not infer missing operations from memo/sign/amount, or treat
  retained rows as UI usage frequency.

## Storage (user decision: 2026-10-20)

User decision (2026-10-24): the household book is the line-based `book.txt` shared with LOAM
(`docs/COMMON_FORMAT.ja.md`), with the accounting roles and Attention as its sections, rewritten
whole on every save with a save target of ≤100 ms. A change to its format needs an explicit,
user-approved migration of `../bakhlo-data` (Principles).

- One book file, `book.txt`: every save writes a temporary file, flushes it, keeps the current
  file as `.prev`, renames and flushes the directory (`Book_file.publish`). No append log,
  Records, annual files or SQLite; long-term history is Git's job. The session keeps the
  in-memory book, whose state is the admitted book.txt (`Daily_book` over
  `Book_txt.book`): a save checks and prints only what it changes. `Book_txt.change`
  must admit exactly what reading the whole printed file admits, and `Book_txt.quantity`
  must equal the specification's balance (`test/book_txt_tests.ml`). An
  S-expression book is refused, never converted on load (the one-time migration tool,
  `tools/book-txt`, is in Git history up to `6a22ba6`).
- Targets: a save ≤100 ms including the durable flush (user decision 2026-10-24; review
  the storage when it is exceeded), key response ≤16 ms, startup ≤100 ms, measured at
  the household's size and at ~30 years (~110k entries). User decision (2026-10-21): every household write
  flushes the drive cache (`F_FULLFSYNC` on macOS, ~21 ms here) before it is reported. Measure with `./tools/startup-probe`. Startup is deferred by the user until
  it is felt slow; then a disposable snapshot first, lazy older years only if needed.
- Every `Daily_book` mutation must agree with the cold reload of its book.txt: keep
  `test/daily_book_oracle_tests.ml` green and extend it before adding a fast path. Its
  admission is `Book_txt.change` (the whole-file rules) after Bakhlo's write policies;
  no second admission engine, dummy Events or surrogate correction histories.
- Persistent post-save acknowledgement (P7) and power loss stay unqualified and
  separate from everyday work.

## Data and authority

- Cutover (user decision 2026-10-21): the operational household is `../bakhlo-data`
  (imported once by `./tools/import-loam`; see its `LOAM-RECORD.md`). The AI never
  writes it; only the user records through the TUI. AI checks use copies in ignored
  scratch. The user opens it with `./tools/household`, which on exit commits changes and
  pushes them to the private GitHub backup `shumoku88-bit/bakhlo-data` (user decision
  2026-10-21); never make that repository public. `../loam-data` is the frozen LOAM
  reference except for an explicit user-requested reflection of Bakhlo recording
  history (user decision: this conversation). For that request, AI may write the LOAM
  original through canonical LOAM commands/publishers, after preserving a recoverable
  backup and checking duplicates, corrections, reversals and payment-plan links.
  Never edit canonical `.loam` bytes directly or guess unsupported operations.
  Bakhlo remains the operational authority; this permits no automatic synchronization
  or other recovery/write. Read-only copies and bounded retained-operation inventory
  remain approved. Keep private data and counts in ignored scratch only; never in fixtures,
  commits or public output. User decision (2026-10-20): no private household text
  (names, memos, identifiers, amounts) may enter this repository, its history or commit
  messages. `./tools/check` runs `./tools/privacy-scan` on changed files; run
  `--all` after broad doc edits. Never put private text in the scan's inputs or output.
  User decision (2026-10-21): scratch trials and captures are disposable (no rule keeps
  them); research, experiments and code off the daily-use path (Irmin, formal models, old CLI)
  live in Git history only.
- Ordinary tests use synthetic inputs. Do not build/modify the sibling Lean repository
  or copy its source without separate authorization.
- No new dependency, release or production adoption by implication.

## Development

- Prefer direct native OCaml and existing tests; no Python (use OCaml, shell or
  Expect). Add a tool or harness only for a concrete gap.
- Keep calculations pure and I/O explicit; keep inward dependencies, useful `.mli`
  boundaries, strict sequencing and fatal warnings 8/9/11. Never suppress errors to make
  an unsupported case pass. See `docs/LANGUAGE_AWARE_DESIGN_REVIEW.md` when relevant.
- Use `./tools/bootstrap`, `./tools/opam`, `./tools/check`; no global environment
  changes. Never commit environments, build output, scratch, credentials or private
  logs; scratch stays excluded from Dune and Git. For long output use `rtk git/gh`,
  `rtk test`, `rtk err` (`sqz` otherwise, not stacked).
