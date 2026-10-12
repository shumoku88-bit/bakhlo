# Instructions for the next pit

`pit` means an AI coding assistant. Read README and `docs/HANDOFF.md` first.
Read the nearest implementation/interface and relevant semantic contract sections
for the task. Architecture, verification, references and learning notes are
on-demand references, not a compulsory reading list or an implementation backlog.

## Current status

- **Completed & Merged**: Trial 06, PR 5 (records format, durable append, application/TUI integration, incremental admission), PR 6 (records strip bytes copy optimization, entry indexing via immutable Map & reversed list), PR UX-1 (natural Japanese error display, field targeting, fail-closed draft preservation), and PR UX-2 (flexible amount parsing with half/full-width & 3-digit commas, flexible date parsing with YYYY-MM-DD / YYYY/MM/DD / YYYY.MM.DD & Gregorian validation, 't' key today reset, Command Palette calendar navigation with pure calendar arithmetic).
- **UI direction**: Reproduce LOAM's current appearance and usability, including Calendar Home with Day / Month / Year, hierarchical Commands and corresponding supported-workspace flows. English comes first; whether to provide a Japanese UI is undecided. Bonsai is the first implementation, not an exclusive frontend decision; a later Notty implementation remains possible. Read `docs/UI_DIRECTION.ja.md` before UI work. Bakhlo is not operationally adopted; obsolete UI mechanisms need no backward compatibility. This does not authorize changing LOAM originals or operational cutover.
- **UI entrance**: `./tools/tui` builds and runs the Bonsai_term frontend in the existing isolated environment. The standalone Notty frontend, paired UI benchmark and old Bonsai layout lab are removed. Notty remains a transitive rendering library and is used by native renderer checks. The renderer does not own accounting logic.
- **Current checkpoint**: Home and basic Record / Preview polish are locally verified. The user asked to stop at a good boundary; do not start another feature slice. Read LOAM's existing research on when sharing is useful or harmful before choosing abstraction boundaries; sharing itself is not a goal. Removing the old Notty renderer does not exclude a later renderer for the new UI.
- **Craft direction**: Use LOAM's proven household semantics and interaction knowledge to build a clean, restrained, modern TUI that benefits from native Bonsai capabilities. Polish spacing, alignment, focus/caret, selection-following scroll, feedback stability, resize, return context and draft retention as observable usability details. The old UI need not return; Notty may follow later. Do not turn this direction into mandatory universal components or a completed-quality claim.
- **Next candidate (UX-3)**: Calculator expression input (`500+300`, `1000*2`) is designed in `docs/UX3_CALCULATOR_INPUT_DESIGN.ja.md` using exact rational/integer quanta (`Q.t` / `Z.t`) without floats, implicit rounding, or zero-division, but is **intentionally deferred and unimplemented**.
- **P7 unresolved safety issue**: Persistent acknowledgement evidence (post-save Ack loss verification) remains an unresolved, independent safety issue. Keep it separate from everyday UX work.
- **Current scope**: Budget allocation/routing APIs and trial v4 support were removed. Daily_book reads v1..v3 and Records v1; its monolithic writer uses v3. Daily Pace and payment plans remain supported.
- **Current UI**: The English foundation uses Calendar Home, Day / Month / Year, hierarchical Commands and one Record / Preview flow over the existing publisher. Actual, current-open Scheduled, Selected Day, Balances and current Daily Pace are connected. Role-aware money-calendar totals, full Series management, Attention, historical Trend and Japanese locale switching remain unavailable. Verify the native build and synthetic cases; foundation completion is not full LOAM parity.
- **Next work**: Refine LOAM compatibility under the current direction, using synthetic ledgers (`examples/daily-book.sexp`). UX-3 and new accounting capabilities remain separate work.
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
- Implement one usable step at a time. No textbook-driven abstractions, automatic
  LOAM accounting feature parity, permanent correction-history requirement, multi-backend
  framework or speculative AI/voice/network/runtime work.
- For Daily_book, prefer existing pure semantic predicates over dummy Events,
  surrogate correction histories or a second admission engine. Any shortcut
  must preserve the full oracle's refusals; add caches/indexes only for measured
  daily-use pressure, not speculative performance.
- The new daily-data candidate may contain corrected entries rather than correction
  chains. Keep the original LOAM data/capture separately. Existing codec/API
  contracts still apply to their current formats; do not silently change them.
- Exact quantities, distinct currencies, unknown versus zero and actual refunds/
  cancellations matter. Do not guess missing facts, round amounts, trim identities
  or silently skip unsupported input. Preserve meaningful payment-plan links.

## Data and authority

- LOAM remains the operational authority. Do not write/recover/migrate/synchronize
  its originals or switch ordinary recording without explicit approval.
- Current user approval covers a stopped, read-only capture of `household.loam`,
  `config/measure-presentation.tsv` and `config/locus-catalog.tsv`, and creation of
  a private Bakhlo candidate. Private inputs/results remain in ignored scratch,
  with restrictive permissions; never fixtures, commits or public output.
- Ordinary tests use synthetic inputs. Do not build/modify the sibling Lean
  repository or copy its source without separate authorization/licensing.
- No new dependency, production storage/UI adoption, release or push by implication.
  Local commits are allowed; do not include another person's unchecked edits.

## Development

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
