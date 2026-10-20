# Instructions for the next pit

`pit` means an AI coding assistant. Read README and `docs/HANDOFF.md` (current
state) first, then the nearest implementation/interface and the relevant parts of
`docs/SEMANTIC_CONTRACT.md`. Other docs are on-demand references, not a reading
list or a backlog. This file holds rules and user decisions only: put status in
HANDOFF or the ledgers and evidence in `docs/VERIFICATION.md`, never here.

## Principles (user decision: 2026-10-20)

- Bakhlo is not in daily use. Destructive changes to Bakhlo's own code and formats
  are allowed; prefer deleting obsolete paths to keeping compatibility.
- LOAM is a behavioral reference, not a source of bugs, unsafe behavior or poor UX
  to reproduce. Keep an intentional safer or more correct difference when justified;
  document and test the difference instead of silently calling it parity.
- Before adding a mechanism, check, document or safety layer, ask what can be removed
  instead. Do not grow a protocol, format or doc to work around an earlier choice.
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
  (`core.yml`: Core build/tests; `tui.yml`: Linux OxCaml/Bonsai build + synthetic
  self-check, opt-in `BAKHLO_BONSAI_CI=1`). Core green ≠ TUI green; synthetic green ≠
  physical-terminal, IME, paired-parity or P7 acceptance. Investigate failures.
- Parallel AI work: agree file/function ownership first; shared Shell/API changes are
  serialized. Per-screen state/input/painting live in `tui/screens/<screen>`.

## Latest-data comparison (user decision: 2026-10-19)

- At a day's start, or after ordinary LOAM data changes, run `./tools/compare refresh`
  (read-only copy of the household/config; LOAM may stay open; changed input refuses
  and keeps the previous CURRENT). Use that one generation for before/after checks.
- Compare Bakhlo (`./ui`) and LOAM (`./ui loam`) on their private copies from the same
  generation for changed screens and for Core changes affecting displayed answers, at
  the user's normal and a narrow geometry. Read-only flows only unless the user
  explicitly asks for writes; verify household/config bytes are unchanged afterwards.
- Then close only the AI's processes and run `./tools/compare clean-copies`. Never
  fall back to originals or an old capture; never terminate the user's LOAM.
- Keep private inputs, captures and results in ignored scratch; record only build
  identity, freshness, dimensions, flows, non-private findings and limits. If copying
  or a binary is unavailable, record **latest-data paired comparison not executed**.
- This workflow authorizes no scheduler or automatic sync, and no deletion of earlier
  trials or captures.

## Product

- Reproduce LOAM's user-facing non-budget functionality, appearance and interaction
  (recording/editing, plans, balances, Daily Pace, reports, Calendar Home Day/Month/
  Year, hierarchical Commands). Budget allocation/transfer/consumption/routing and the
  Budget Window wait until actually needed — no speculative budget code. Fava and
  hledger export are out of scope (other output/diagnostics are not, without a
  separate decision). Internal structures need not match LOAM; observable results and
  safety behavior must. Cutover is a separate decision (`docs/CUTOVER_CHECKLIST.ja.md`).
- Today's spending guide is LOAM Home `d` Daily Pace. `docs/UI_DIRECTION.ja.md` owns UI
  policy: English first (Japanese undecided), Bonsai first (Notty may follow), quiet
  colors, stable geometry, preserved drafts/selection, visible safety errors. Share UI
  mechanics only when current callers justify it (`tui/README.md`).
- Exact quantities, distinct currencies, unknown versus zero, real refunds and
  cancellations matter. Never guess facts, round amounts, trim identities or skip
  unsupported input. Preserve payment-plan links and stable IDs.
- Use observed household needs to order work, not to drop LOAM features from the
  parity inventory. Do not infer missing operations from memo/sign/amount, or treat
  retained rows as UI usage frequency.

## Storage (user decision: 2026-10-20)

- One book file: the single-file S-expression book followed by appended records
  (`Bakhlo_sexp.Book_log`, `Daily_file.append`). No Records, annual hash-chained files
  or SQLite. One `.prev` is kept at compaction; long-term history is Git's job. An
  interrupted final record stops writes until explicitly discarded (no auto-repair).
  Compaction runs on TUI exit at 200+ records.
- Targets at ~30 years (~110k entries): save ≤5 ms, key response ≤16 ms, startup
  ≤100 ms. Measure with `./tools/startup-probe`. Startup is deferred by the user until
  it is felt slow; then a disposable snapshot first, lazy older years only if needed.
- Every `Daily_book` mutation must agree with `Daily_book.Full` and with a cold reload:
  keep `test/daily_book_oracle_tests.ml` green and extend it before adding a fast path.
  Reuse the existing semantic checks (e.g. run `Actual_source` on the changed entries);
  no second admission engine, dummy Events or surrogate correction histories.
- Persistent post-save acknowledgement (P7) and power loss stay unqualified and
  separate from everyday work.

## Data and authority

- LOAM remains the operational authority. Never write, recover, migrate or synchronize
  its originals, switch ordinary recording, or perform a cutover without explicit
  approval. Approved: read-only copies of `household.loam` and its config, fresh
  private comparison copies, and bounded read-only inventory of retained operation
  evidence. Keep private data and counts in ignored scratch only; never in fixtures,
  commits or public output. User decision (2026-10-20): no private household text
  (names, memos, identifiers, amounts) may enter this repository, its history or commit
  messages. `./tools/check` runs `./tools/privacy-scan` on changed files; run
  `--all` after broad doc edits. Never put private text in the scan's inputs or output. Preserve earlier captures, candidates, trial edits and the
  Irmin research artifacts.
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
