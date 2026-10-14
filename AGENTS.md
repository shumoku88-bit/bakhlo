# Instructions for the next pit

`pit` means an AI coding assistant. Read README and `docs/HANDOFF.md` first.
Read the nearest implementation/interface and relevant semantic contract sections
for the task. Architecture, verification, references and learning notes are
on-demand references, not a compulsory reading list or an implementation backlog.

## Current status

- **Completed & Merged**: Trial 06, PR 5 (records format, durable append, application/TUI integration, incremental admission), PR 6 (records strip bytes copy optimization, entry indexing via immutable Map & reversed list), PR UX-1 (natural Japanese error display, field targeting, fail-closed draft preservation), and PR UX-2 (flexible amount parsing with half/full-width & 3-digit commas, flexible date parsing with YYYY-MM-DD / YYYY/MM/DD / YYYY.MM.DD & Gregorian validation, 't' key today reset, Command Palette calendar navigation with pure calendar arithmetic).
- **UI direction**: Reproduce LOAM's current appearance and usability, including Calendar Home with Day / Month / Year, hierarchical Commands and corresponding supported-workspace flows. English comes first; whether to provide a Japanese UI is undecided. Bonsai is the first implementation, not an exclusive frontend decision; a later Notty implementation remains possible. Read `docs/UI_DIRECTION.ja.md` before UI work. Bakhlo is not operationally adopted; obsolete UI mechanisms need no backward compatibility. This does not authorize changing LOAM originals or operational cutover.
- **UI entrance**: `./ui` opens a private comparison copy; `./ui loam` opens the paired LOAM copy with the existing binary, and `./ui --refresh` performs an explicit stopped read-only capture using the earlier private converter. Missing/unsupported/changed inputs refuse, without live or synthetic fallback. `./ui --demo` retains the synthetic preview. `./tools/tui` builds and runs the Bonsai_term frontend in the existing isolated environment. The standalone Notty frontend, paired UI benchmark and old Bonsai layout lab are removed. Notty remains a transitive rendering library and is used by native renderer checks. The renderer does not own accounting logic.
- **Current checkpoint**: Home and basic Record / Preview polish are locally verified. Storage baseline/decomposition/printer probes and Irmin Phase 1/limited Phase 2 are complete. Irmin product integration is on hold after partial-HEAD-write failures; durable Saved/power-loss/P7 remain unqualified. The next first candidate is [calendar-year partitioned S-expressions](docs/YEAR_PARTITIONED_SEXP_RESEARCH.ja.md), with SQLite retained for comparison. This is research direction only, not adoption. Storage authorization covers document/reproducibility preservation, not year-partition implementation or data changes. The user separately authorized today's completed UI work to be committed on main, pushed and merged branches cleaned; that is not storage adoption or household cutover. The completed bounded private inventory remains ignored (`scratch/operation-inventory-leEhTN/priorities.private.md`); never publish its counts/findings or treat it as a full UI frequency log. Paired comparison freshness is not requalified. Sharing itself is not a goal; the old Notty renderer need not return.
- **Craft direction**: Use LOAM's proven household semantics and interaction knowledge to build a clean, restrained, modern TUI that benefits from native Bonsai capabilities. Polish spacing, alignment, focus/caret, selection-following scroll, feedback stability, resize, return context and draft retention as observable usability details. The old UI need not return; Notty may follow later. Do not turn this direction into mandatory universal components or a completed-quality claim.
- **Next candidate (UX-3)**: Calculator expression input (`500+300`, `1000*2`) is designed in `docs/UX3_CALCULATOR_INPUT_DESIGN.ja.md` using exact rational/integer quanta (`Q.t` / `Z.t`) without floats, implicit rounding, or zero-division, but is **intentionally deferred and unimplemented**.
- **P7 unresolved safety issue**: Persistent acknowledgement evidence (post-save Ack loss verification) remains an unresolved, independent safety issue. Keep it separate from everyday UX work.
- **Current scope**: Budget allocation/routing APIs and trial v4 support were removed. Daily_book reads v1..v3 and Records v1; its monolithic writer uses v3. Daily Pace and payment plans remain supported.
- **Current UI**: Fixed bonsai Home, Calendar Day / Month / Year, hierarchical Commands and Record / Preview use the existing publisher. Actual, single-occurrence Scheduled create/edit/cancel/complete, Balances/Observe, current Pace/What-if/Pool edits, Manage Loci/explicit role settings, Exchange, Attention and limited cumulative-commitment settlement trial are connected. Role-aware Calendar totals, full Series/Months, historical Trend, broader reports, OriginalAmount/Merchant and Japanese locale switching remain unavailable. The updated cutover inventory separates these axes; source presence is not full parity.
- **Current parity work**: User selected LOAM-quality non-budget everyday features, excluding bonsai growth and budget/routing. First safety slice repairs Attention/settlement refusal and save-result handling, stale-state checks, explicit Pace conditions and negative What-if. Pool editing writes only daily-pace.tsv and preserves all boundary presets; no multi-file transaction was introduced. Existing synthetic Core/UI checks passed; full LOAM runtime parity/manual acceptance, sidecar power loss/P7 and role-setting persistence remain unqualified. Continue one workspace at a time from the updated inventory; do not infer cutover approval.
- **Shared UI mechanics**: `tui/ui_panel.ml/.mli` owns framed viewport capacity, selection-following painting and bounded offset motion. Actual and Scheduled share these rules; content, identities, keys, draft/Preview refusal and publication remain outside. Reuse existing primitives instead of another screen engine. Core/UI and synthetic PTY checks passed; paired visual/manual acceptance remains open. See `tui/README.md` for KEEP/DEFER boundaries before extending sharing.
- **Reversal safety (P05)**: `reversal_session.ml/.mli` owns local Date/fixed-target Preview and end/tiny gates; only the existing writer builds the durable inverse. Preserve the captured base on reload, stop on uncertainty, and do not lose held Record drafts. `bonsai_daily.ml` uses dynamic input dimensions at action application: a captured event-handler dimension admitted publication after a PTY shrink. Record paint/form/writers are not part of this fix; other action modals and paired visual/manual acceptance remain unqualified.
- **Parallel UI delegation**: `docs/LOAM_UI_GAP_LEDGER.ja.md` owns UI-01..33 source-aligned F/O/V/Q gaps and P01..P08 bounded assignment cards. Agree file/function ownership before edits; different screens share `daily_interaction.ml`, common components and checks. Read-only comparison/design work can run in parallel; shared-file/API changes require serialized integration. Preserve prior Home/Commands work. Series/Months/Pace history are unconnected, not screenshot-only gaps; generic modals do not inherit Record Preview's publication gate. This inventory is source/record review, not new LOAM runtime parity or authority.
- **Storage work (separate)**: Consult the user before implementing the [year-partition synthetic comparison](docs/YEAR_PARTITIONED_SEXP_RESEARCH.ja.md): 2025-10-15–2026-10-14, six two-month cycles, single S-expression control vs calendar-year data plus qualified opening evidence. Storage years are Jan 1–Dec 31; adopted pension payment dates are independent cycle boundaries, not always the 15th. Cross-year Scheduled/Actual links, unknown/zero/cut/root carryover, past-correction invalidation and multi-file atomicity/recovery must be explicit. [Canonical design](docs/CANONICAL_DATA_DESIGN.ja.md) owns meaning/reference closure and LOAM reuse; [storage study](docs/LONG_TERM_STORAGE_STUDY.ja.md) owns costs. Inherit earned laws/counterexamples/writer refusals, not a second semantic engine. Historical decode is not writer permission and root-cut stability is not OpeningSupport inheritance. No full refund/settlement mandate, generic persistence framework, new root manifest, dependency installation or adoption by implication. Existing Irmin scratch/switch/failures and all originals/trials remain preserved. UI refinement, UX-3 and new capabilities are separate.
- **Operational authority**: LOAM continues to manage production authority and live household data. Bakhlo is evaluated on synthetic data and private candidates. Never modify production originals.

## Product

- Build an ordinary household ledger around recording/editing and payment plans,
  with various balances, LOAM Daily Pace and reports selected for actual household
  needs. Budget allocation and purpose routing are deliberately absent
  from Bakhlo. Obsolete experimental budget-only inputs may be recreated
  instead of migrated. Daily Pace and payment plans remain central.
  The prior Attention request remains; detailed scope and cutover conditions live
  in `docs/CUTOVER_CHECKLIST.ja.md`. Small means direct, readable implementation,
  not dropping needed household functions.
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
- Implement current frequently used operations first, informed by the authorized
  read-only canonical-history inventory; add unused features only when needed.
  Preserve stable identities, independent evidence/reference boundaries, original
  archives and explicit version migrations so later additions are not blocked by
  premature information loss. This does not require speculative fields or a generic
  extension framework, and history is not a complete UI/use-frequency log.
  No textbook-driven abstractions, automatic LOAM accounting feature parity,
  permanent correction-history requirement, multi-backend framework or speculative
  AI/voice/network/runtime work.
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
- Current user approval covers stopped, read-only captures of `household.loam`
  and its regular config files, fresh private Bakhlo/LOAM comparison copies, and
  bounded read-only inventory of retained operation evidence to identify current
  use priorities. Keep raw inputs and private counts/results in restricted ignored
  scratch; never fixtures, commits or public docs/output. Do not infer missing
  operations from memo/sign/amount or equate retained/imported rows with UI frequency.
  Preserve earlier captures/candidates and trial edits; no live or silently stale
  fallback, automatic sync, full migration or operational cutover. All LOAM instances
  must be closed for a fresh capture; never terminate user processes.
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
