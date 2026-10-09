# Instructions for the next pit

`pit` means an AI coding assistant. Read README and `docs/HANDOFF.md` first.
Read the nearest implementation/interface and relevant semantic contract sections
for the task. Architecture, verification, references and learning notes are
on-demand references, not a compulsory reading list or an implementation backlog.

## Current status (as of PR UX-2 merge on main)

- **Completed & Merged**: Trial 06, PR 5 (records format, durable append, application/TUI integration, incremental admission), PR 6 (records strip bytes copy optimization, entry indexing via immutable Map & reversed list), PR UX-1 (natural Japanese error display, field targeting, fail-closed draft preservation), and PR UX-2 (flexible amount parsing with half/full-width & 3-digit commas, flexible date parsing with YYYY-MM-DD / YYYY/MM/DD / YYYY.MM.DD & Gregorian validation, 't' key today reset, Command Palette calendar navigation with pure calendar arithmetic).
- **Dual TUI parity**: Notty and Bonsai_term are co-equal official TUIs sharing the application and interaction layer (`daily_actions.ml`, `daily_interaction.ml`, `daily_overlays.ml`, `daily_browser.ml`, `daily_form.ml`, `posting_editor.ml`). Neither frontend owns accounting logic. Both frontends must pass `./tools/tui --self-check`.
- **Next candidate (UX-3)**: Calculator expression input (`500+300`, `1000*2`) is designed in `docs/UX3_CALCULATOR_INPUT_DESIGN.ja.md` using exact rational/integer quanta (`Q.t` / `Z.t`) without floats, implicit rounding, or zero-division, but is **intentionally deferred and unimplemented**.
- **P7 unresolved safety issue**: Persistent acknowledgement evidence (post-save Ack loss verification) remains an unresolved, independent safety issue. Keep it separate from everyday UX work.
- **Next work**: Do not rush to implement new features or start UX-3 immediately. Start by testing everyday recording and browsing operations on synthetic ledgers (`examples/daily-book.sexp`).
- **Operational authority**: LOAM continues to manage production authority and live household data. Bakhlo is evaluated on synthetic data and private candidates. Never modify production originals.

## Product

- Build an ordinary household ledger around recording/editing and payment plans,
  with various balances, LOAM Daily Pace and reports selected for actual household
  needs. The user wants to test whether this combination suffices in real use
  WITHOUT budget allocation. Budget UI/expansion is deferred, not a cutover
  prerequisite; budget may remain unused. Preserve existing budget APIs/data
  contracts; this is not authorization to delete code or retained information.
  The prior Attention request remains; detailed scope and cutover conditions live
  in `docs/CUTOVER_CHECKLIST.ja.md`. Small means direct, readable implementation,
  not dropping needed household functions.
- Today's spending guide is LOAM Home `d` Daily Pace, not a purpose-budget guide.
  TUI Home has upper recording and a large lower browsing region. Tab switches
  regions; arrows operate within one region. Keep only the selected lower feature's
  content and focused-region help; use floating panes for picker/detail/preview.
  Preserve drafts, selection and visible safety errors. Notty and Bonsai_term are
  co-equal official TUIs sharing pure interaction logic; new panes use shared state
  updates and pure formatting. See the checklist's design section.
- Implement one usable step at a time. No textbook-driven abstractions, automatic
  LOAM feature parity, permanent correction-history requirement, multi-backend
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
