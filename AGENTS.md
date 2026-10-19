# Instructions for the next pit

`pit` means an AI coding assistant. Read README and `docs/HANDOFF.md` first.
Read the nearest implementation/interface and relevant semantic contract sections
for the task. Architecture, verification, references and learning notes are
on-demand references, not a compulsory reading list or an implementation backlog.

## Ordinary development loop (user decision: 2026-10-18)

- This is a single-maintainer workflow: work on `main`, and **commit/push small, reviewed and tested slices directly to main**. Do not create a branch or PR for ordinary changes. Use isolation for a large experiment, risky change or conflicting parallel AI work; never force-push. This supersedes historical PR-first examples, not storage/cutover protections.
- At the beginning of a pass, inspect remote HEAD, pending edits and `tasks/todo.md`, then use `docs/LOAM_UI_GAP_LEDGER.ja.md` as the sole per-screen gap/state ledger. `docs/VERIFICATION.md` records what actually ran. The priority is unfinished Daily Pace/Balances acceptance and then systematic non-budget LOAM parity.
- Choose one bounded ready F/O/V/Q slice, read its source owner and dependencies, preserve existing features, and add narrow regression checks. Use synthetic inputs, `./tools/check`, TUI self-check and paired LOAM binary where available. If no executable environment is available, explicitly record **not executed** and do not declare acceptance; the next worker must run tests before relying on the result.
- `docs/CUTOVER_DIFF_LEDGER.ja.md` is the user's pre-cutover LOAM difference summary for the five daily-use areas (Record, Scheduled, Loci, Balances, Daily Pace) plus cutover conditions. Update its rows in the same slice whenever a difference is found, fixed or compared; keep details in the UI ledger and VERIFICATION and only link them.
- After verifying, update the existing ledger and evidence, then commit/push the slice to `main`. Distinguish code connected, tests passing, paired runtime acceptance and human/IME acceptance. Never fabricate a success, infer a missing balance, or silently weaken Preview/save refusal.
- Never modify LOAM originals or private production household data, change live-data authority, perform a cutover or migration, add dependencies or overwrite another worker's uncommitted edits by implication. Fresh private capture and read-only trial navigation follow the authorization below. P7/power loss stays separately unqualified.

## Latest-data comparison during AI development (user decision: 2026-10-19)

- At each day's development start, and when resuming after ordinary LOAM data changes, inspect source/remote status and pending edits, then use `./tools/compare refresh` to copy the latest LOAM household/config read-only. LOAM may remain open; process presence alone is not a refusal. The existing before/after source checks refuse changed input and retain the previous CURRENT. No new locking protocol is needed. The AI compares the copies itself; the user need not run `./ui --daily`. Reuse that generation for before/after checks during the pass. Never terminate a user's LOAM process or write its originals.
- Build the current Bakhlo source with the existing isolated TUI environment and compare it with the existing LOAM executable on their separate private copies from the **same fresh capture generation**. Use `./ui` and `./ui loam` (or the equivalent isolated PTY entrances). Check the changed/relevant screens before and after development, including Core changes affecting displayed answers; include normal Daily Pace/Balances when relevant. Use the user's normal terminal geometry and a narrow geometry when relevant: displayed answers, selection/details, navigation, resize and return context. Use read-only flows; do not add real household transactions or perform other writes unless explicitly requested. Verify household/config bytes remain unchanged after the walk.
- After the comparison, close only the AI's comparison processes and run `./tools/compare clean-copies` to remove the selected generation's temporary LOAM source/view copies. Retain the imported Bakhlo data/config and originals. The removed LOAM view must be freshly copied again before another paired walk; never fall back to originals. This does not authorize deleting earlier trials.
- Keep private inputs, screen captures and results inside restricted ignored scratch; never print raw household content or include it in tracked docs, fixtures, CI artifacts or public output. Record only the source/build identity, capture freshness, dimensions, checked flows, non-private findings and limitations in the existing verification/ledger locations.
- If copying refuses (including source changes during capture), conversion is unsupported or an executable is unavailable, record **latest-data paired comparison not executed**, with the reason. Independent development and synthetic regression checks may continue, but an old capture or synthetic fixture is never a fallback that qualifies as latest-data comparison. Refresh again if ordinary source data changes before the next comparison.
- Synthetic tests remain necessary for regressions and unsupported edge cases. Report latest-real-data paired observation separately from synthetic results, human/IME acceptance, P7 and operational adoption; none implies the others. `./ui --daily` remains an optional user convenience. This standing workflow authorizes no unattended scheduler or automatic sync.

## CI scope (2026-10-18)

- `.github/workflows/core.yml` runs locked OCaml 5.3 Core builds/tests for selected `main` pushes and PRs. `.github/workflows/tui.yml` independently attempts a Linux OxCaml 5.2.0+ox / pinned Bonsai_term build and `./tools/tui --self-check` on relevant tracked-source pushes/PRs. The TUI workflow does not use the locally ignored Mac Bonsai switch or production household files; `BAKHLO_BONSAI_CI=1` is an explicit opt-in for the generated TUI build.
- The first completed Linux TUI run `39094690207` passed the tracked-source build and full synthetic self-check after the `scratch/` fix. A separate compiled dependency cache was added in `4fe9f1d`, but a cache was saved by run `39096625299`, and run `39098165655` demonstrated an exact cache hit plus passing four-dimension PTY step before a subsequent push cancelled its whole workflow; replacement run `39098268276` completed successfully in minutes. Cold-reopen PTY test `9a76e8d` passed all four dimensions in run `39098514176` (including exact current wallet balance and unchanged synthetic ledger bytes). This remains distinct from real macOS IME, paired LOAM acceptance, and power-loss/P7. Do not claim a new source change is qualified merely because the workflow exists or was triggered. Inspect the **matching commit SHA** and run/job result, then investigate failures and preserve their evidence. Core green does not imply Bonsai TUI green. Synthetic self-check green does not imply real PTY key/resize, IME, LOAM paired parity or P7/cutover acceptance.
- The next CI extension, only after the isolated Ox build is reproducible, is a bounded synthetic PTY/key/cold-reopen matrix at 120x36, 80x24, 48x14 and 32x9. Do not use live household data, copy private captures to artifacts or call a synthetic render a physical-terminal acceptance.

## Current status

- **Completed & Merged**: Trial 06, PR 5 (records format, durable append, application/TUI integration, incremental admission), PR 6 (records strip bytes copy optimization, entry indexing via immutable Map & reversed list), PR UX-1 (natural Japanese error display, field targeting, fail-closed draft preservation), and PR UX-2 (flexible amount parsing with half/full-width & 3-digit commas, flexible date parsing with YYYY-MM-DD / YYYY/MM/DD / YYYY.MM.DD & Gregorian validation, 't' key today reset, Command Palette calendar navigation with pure calendar arithmetic).
- **UI direction**: Reproduce LOAM's user-facing functionality, appearance, usability and fine interaction details systematically, including Calendar Home with Day / Month / Year, hierarchical Commands and every non-budget workspace. Only budget allocation/transfer/consumption/routing and Budget Window are deferred until actually needed; Daily Pace, plans and adjacent non-budget features remain in scope. Earlier current-use-only and bonsai-growth exclusions no longer constrain parity. English comes first; a Bakhlo-specific Japanese localization decision remains pending, without excluding observable locale behavior required by LOAM parity. Bonsai is the first implementation, not an exclusive frontend decision; a later Notty implementation remains possible. Read `docs/UI_DIRECTION.ja.md` before UI work. Bakhlo is not operationally adopted; obsolete UI mechanisms need no backward compatibility. This does not authorize changing LOAM originals or operational cutover.
- **UI entrance**: `./ui` opens a private comparison copy; `./ui loam` opens the paired LOAM copy with the existing binary, and `./ui --refresh` copies the latest household/config read-only using the earlier private converter; LOAM need not close. Missing/unsupported/changed inputs refuse, without live or synthetic fallback. `./ui --demo` retains the synthetic preview. `./tools/tui` builds and runs the Bonsai_term frontend in the existing isolated environment. The standalone Notty frontend, paired UI benchmark and old Bonsai layout lab are removed. Notty remains a transitive rendering library and is used by native renderer checks. The renderer does not own accounting logic.
- **Current checkpoint**: Home and basic Record / Preview polish are locally verified. Storage baseline/decomposition/printer probes and Irmin Phase 1/limited Phase 2 are complete. Irmin product integration is on hold after partial-HEAD-write failures; durable Saved/power-loss/P7 remain unqualified. Records v1 (append engine) and calendar-year annual files (`bakhlo-annual 1`, rollover, chain backup) were **removed** on 2026-10-20 (user decision, below); the single-file S-expression book is the only format. Never publish or expand the ignored private inventory.

- **Craft direction**: Use LOAM's proven household semantics and interaction knowledge to build a clean, restrained, modern TUI that benefits from native Bonsai capabilities. Polish spacing, alignment, focus/caret, selection-following scroll, feedback stability, resize, return context and draft retention as observable usability details. The old UI need not return; Notty may follow later. Do not turn this direction into mandatory universal components or a completed-quality claim.
- **Calculator status (UX-3)**: `Daily_book.parse_amount` accepts exact rational arithmetic for amount inputs, projects only positive integer quanta and refuses zero division/indivisible results. Existing Record, Scheduled and other positive-amount UI consumers share it; signed Posting prefixes apply to the entire magnitude. Synthetic Core/native Record checks passed; paired LOAM UI and real IME acceptance remain open. See `docs/UX3_CALCULATOR_INPUT_DESIGN.ja.md` for historical design, not a pending implementation mandate.
- **P7 unresolved safety issue**: Persistent acknowledgement evidence (post-save Ack loss verification) remains an unresolved, independent safety issue. Keep it separate from everyday UX work.
- **Current scope**: Only budget allocation/transfer/consumption/routing and Budget Window are deferred until actually needed, not permanently excluded. Do not restore speculative budget APIs, formats or hooks. The earlier budget APIs and trial v4 support were removed; Daily_book reads v1..v3 and v5; its writer uses v3, or v5 only when explicit bounded-history support is present (v4 stays the removed budget trial and is refused). Daily Pace and payment plans remain in scope.
- **Explicit parity exclusions**: The user does not need Fava or hledger export. Do not implement these or count them as cutover blockers. This does not remove Print/diagnostics or other external formats without a separate decision; retain historical research as history, not a backlog.
- **Current UI**: Fixed bonsai Home, Calendar Day / Month / Year, hierarchical Commands and Record / Preview use the existing publisher. Actual, single-occurrence Scheduled create/edit/cancel/complete and explicit six-month projection, Balances/Observe, current Pace/What-if/Pool edits, Manage Loci/explicit role settings, Exchange, Attention and limited cumulative-commitment settlement trial are connected. Role-aware Calendar totals, full Series/coverage, broader reports and Japanese locale switching remain incomplete. Daily Pace historical Trend, OriginalAmount and Merchant are connected; their LOAM-comparison and human/IME acceptance remain partial. Balances grouped observations and visible-account picker are connected, while the Current/Accounting/Print parity still has residual gaps. Months uses current-open plans only, not inferred recurrence or completeness. `docs/LOAM_UI_GAP_LEDGER.ja.md` owns per-screen progress; source presence is not full parity.
- **Current parity work**: Target all LOAM user-facing non-budget functionality and observable details, not only currently frequent operations or visual polish; bonsai growth is not excluded. The earlier safety slice repaired Attention/settlement refusal and save-result handling, stale-state checks, explicit Pace conditions and negative What-if. Pool editing writes only daily-pace.tsv and preserves all boundary presets; no multi-file transaction was introduced. Existing synthetic Core/UI checks passed for that bounded slice; full LOAM runtime parity/manual acceptance, sidecar power loss/P7 and role-setting persistence remain unqualified. Follow the ordered acceptance plan in `tasks/todo.md`; `docs/LOAM_UI_GAP_LEDGER.ja.md` alone owns per-screen progress. Do not infer cutover approval.
- **Shared UI mechanics**: `tui/ui_panel.ml/.mli` owns framed viewport capacity, selection-following painting and bounded offset motion. Actual and Scheduled share these rules; content, identities, keys, draft/Preview refusal and publication remain outside. Reuse existing primitives instead of another screen engine. Core/UI and synthetic PTY checks passed; paired visual/manual acceptance remains open. See `tui/README.md` for KEEP/DEFER boundaries before extending sharing.
- **Reversal safety (P05)**: `reversal_session.ml/.mli` owns local Date/fixed-target Preview and end/tiny gates; only the existing writer builds the durable inverse. Preserve the captured base on reload, stop on uncertainty, and do not lose held Record drafts. `bonsai_daily.ml` uses dynamic input dimensions at action application: a captured event-handler dimension admitted publication after a PTY shrink. Record paint/form/writers are not part of this fix; other action modals and paired visual/manual acceptance remain unqualified.
- **Parallel UI delegation**: `docs/LOAM_UI_GAP_LEDGER.ja.md` owns UI-01..33 source-aligned F/O/V/Q gaps and P01..P08 bounded assignment cards. Agree file/function ownership before edits; different screens share the Shell (`tui/shell`), common components and checks; per-screen state, input and painting live in `tui/screens/<s>`. Read-only comparison/design work can run in parallel; shared-file/API changes require serialized integration. Preserve prior Home/Commands work. Series/coverage remain unconnected. Pace history is connected, but dated support, historical paid/cancelled plans and human acceptance remain unqualified; Months has a bounded explicit-plan projection. Generic modals do not inherit Record Preview's publication gate. This inventory is not full LOAM runtime parity or authority.
- **Storage direction (user decision: 2026-10-20)**: Bakhlo is not in daily use, so destructive changes to Bakhlo's own formats and code are allowed; prefer deleting obsolete paths over keeping compatibility. Do not reintroduce Records, annual hash-chained files or SQLite (not for now). Performance target is extreme: about 30 years (~110k entries) with startup ≤100 ms, save ≤5 ms and key response ≤16 ms. Order: (1) keep `test/daily_book_oracle_tests.ml` (cold-equivalence oracle) green and extend it first, (2) make every `Daily_book` mutation incremental by construction, (3) append-only operation log plus a disposable snapshot, (4) lazy older years only if measurement requires it. Measure with `./tools/startup-probe` ([stage 5](docs/LONG_TERM_STORAGE_STUDY.ja.md)). This authorizes no live-data migration, LOAM original writes or P7 claims. Existing Irmin scratch/switch/failures and all LOAM originals/trials remain preserved.

- **Operational authority**: LOAM continues to manage production authority and live household data. Bakhlo is evaluated on synthetic data and private candidates. Never modify production originals.

## Product

- Reproduce LOAM's user-facing household functionality, appearance and interaction,
  including recording/editing, plans, balances, Daily Pace, reports and other inventory
  gaps. Only budget allocation/transfer/consumption/routing and Budget Window wait
  until actually needed; do not add speculative budget infrastructure. Daily Pace
  and plans are not deferred with budgets. Prior current-use-only and bonsai-growth
  exclusions are superseded. Small means direct, readable implementation, not
  dropping parity requirements. Internal structures, proof machinery and storage
  need not match LOAM; observable results and safety behavior must.
  Operational adoption remains a separate decision in `docs/CUTOVER_CHECKLIST.ja.md`.
  Fava and hledger export are explicitly out of scope; do not infer that all
  external output or diagnostic printing is excluded.
- Today's spending guide is LOAM Home `d` Daily Pace, not a purpose-budget guide.
  Use quiet terminal-owned colors, thin rounded muted frames, one focus accent,
  stable geometry and contextual bottom operations with reserved wrapping feedback.
  Preserve drafts, selection, exact quantities and visible safety errors; use transient
  panes for recording/picker/detail/preview. The target Home is LOAM's Calendar
  with Day / Month / Year and a focused transaction detail region; Commands is
  hierarchical, and shared capabilities use LOAM's workspace labels, navigation,
  confirmation and return behavior. The English foundation is connected; calendar
  markers count Actual/open Scheduled without inventing income/expense roles.
  Do not describe the remaining LOAM features as implemented. Japanese UI is undecided.
  Bonsai comes first; Notty may follow. Share only mechanics whose current callers and
  semantics justify sharing; consult LOAM's research before factoring editing screens.
  `docs/UI_DIRECTION.ja.md` owns the UI policy; historical UI roadmaps do not bind the new design.
- Use observed household needs to order the work, not to exclude LOAM user-facing
  features from the parity inventory. Preserve stable identities, independent
  evidence/reference boundaries, original archives and explicit version migrations
  so implementation order does not destroy needed information. History is not a
  complete UI/use-frequency log. Do not add speculative fields or a generic extension
  framework. LOAM parity does not require matching internal accounting structures,
  permanent correction history, textbook-driven abstractions, multi-backend machinery
  or unrelated AI/voice/network/runtime work.
- For Daily_book, prefer existing pure semantic predicates over dummy Events,
  surrogate correction histories or a second admission engine. Any shortcut
  must preserve the full oracle's refusals; add caches/indexes only for measured
  daily-use pressure, not speculative performance.
- The new daily-data candidate may contain corrected entries rather than correction
  chains. Keep the original LOAM data/capture separately. Existing codec/API
  contracts still apply to their current formats; do not silently change them.
- Normal editing is through TUI/other application entrances. The user sees little
  readability difference between S-expression and row syntax; do not prioritize manual
  readability/editing comfort in format selection. Compare equal-operation save/correction
  costs, memory, backup growth, recovery/migration and implementation/maintenance instead.
  Portable reading/diagnostics remain useful; syntax and physical storage are separate.
- Exact quantities, distinct currencies, unknown versus zero and actual refunds/
  cancellations matter. Do not guess missing facts, round amounts, trim identities
  or silently skip unsupported input. Preserve meaningful payment-plan links.

## Data and authority

- LOAM remains the operational authority. Do not write/recover/migrate/synchronize
  its originals or switch ordinary recording without explicit approval.
- Current user approval covers read-only copies of `household.loam`
  and its regular config files, fresh private Bakhlo/LOAM comparison copies, and
  bounded read-only inventory of retained operation evidence to identify current
  use priorities. Keep raw inputs and private counts/results in restricted ignored
  scratch; never fixtures, commits or public docs/output. Do not infer missing
  operations from memo/sign/amount or equate retained/imported rows with UI frequency.
  Preserve earlier captures/candidates and trial edits; no live or silently stale
  fallback, automatic sync, full migration or operational cutover. LOAM may remain
  open while copying; refuse changed inputs using existing before/after checks.
  Never terminate user processes or write originals.
- Ordinary tests use synthetic inputs. Do not build/modify the sibling Lean
  repository or copy its source without separate authorization/licensing.
- No new dependency, production storage/UI adoption, release or push by implication.
  Local commits are allowed; do not include another person's unchecked edits.

## Development

- For relevant code changes and occasional runtime review, follow [OCaml-aware design review](docs/LANGUAGE_AWARE_DESIGN_REVIEW.md) (issue #28): narrow checks and measured evidence, not automatic optimization or a new mandatory pipeline.
- Prefer direct native OCaml and existing tests. Do not use Python, including
  ad-hoc tooling or test scripts; use OCaml, shell or the existing Expect instead.
  Add a tool, model or test harness only for a concrete gap. No mandatory D/P/R
  document or all-tools pipeline.
- Keep calculations pure and I/O explicit. Preserve inward dependencies, useful
  `.mli` boundaries, strict sequencing and fatal warnings 8/9/11. Normal builds
  remain Lean-free. Never suppress errors to make an unsupported case pass.
- Use `./tools/bootstrap`, `./tools/opam`, `./tools/check`; no global environment
  changes. Use the existing optional formatter for layout-only work.
- Check the changed behavior and review the exact diff. Report failures/limits.
  Update current instructions, not a running diary. Git owns obsolete roadmaps;
  retain useful tests and verification counterexamples as references.
- Never commit environments, build output, scratch, credentials or private logs.
  Scratch must stay excluded from Dune as well as Git. For long output use
  `rtk git/gh`, `rtk test`, `rtk err`; use `sqz` only otherwise, not stacked.
