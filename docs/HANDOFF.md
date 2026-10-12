# Handoff

## Current task

Research canonical-data logical design and select a long-term storage direction before
expanding UI work. [Canonical data design](CANONICAL_DATA_DESIGN.ja.md) owns retained facts,
reference/correction candidates, the five-case logical model draft, native minimal pairs
and the first bounded Alloy slice. **Current-use-first is the user's selected direction**:
implement the operations they commonly perform now, then add unused features when needed.
Do not require all refund/post-discharge scopes to be decided before storage research.
Preserve identity/evidence boundaries, original archives and explicit version migrations
so later additions are not blocked by premature information loss; no generic extension framework.
The user authorizes a bounded read-only canonical-history inventory from fresh stopped private
captures to identify current priorities. Keep private counts/results in restricted ignored
scratch; canonical history is not a complete UI operation/read-frequency log. The fresh
stopped capture and bounded inventory are complete at `scratch/operation-inventory-leEhTN`.
Read its `priorities.private.md` and `details-v2/INVENTORY_COMPLETE` for private priorities
and scope; do not transcribe household counts/usage findings into public docs or tests.
Existing Actual/four-support read admission and the private Scheduled reader were reused;
Attention is row-shape inventory only, other families preserved opaque. This is not full
LOAM admission, whole migration, restore qualification, or cutover.
Start from this inventory and the **LOAM asset reuse table**, not another investigation of
already-earned semantics. The household operation draft is a future-extension reference,
not an adopted capability list or a requirement to implement every row before cutover.
The native probes qualify OCaml connections and
candidate representation failures; they are not new discoveries of LOAM household meaning.
LOAM's current CorrectionPublisher already refuses Relation/Discharge-referenced and Reversal
participant corrections; historical decode representability is not writer permission.
Candidate C has no implemented combined admission. Qualify only the reduced-history mapping,
root/reference closure and especially OpeningSupport staleness/re-support before syntax work.
Do not generalize correction-stable anchors into automatic inheritance of all support.
Alloy found unsafe retargeting and partial source-row retention; its successful complete-row
check is conditional on the documented full-row premise, not a proof of candidate C.
Existing optional Lean root-cut laws were rechecked; new compaction proofs are not earned.
Use TLA+ when concrete publication/recovery transitions need qualification, not as another
structural check. `formal/README.md` owns the optional tool entrances; normal builds stay Lean-free.
Establish the same logical information before comparing S-expression with row-oriented syntax; the earlier
S-expression selection is reopened for research, not replaced by an adopted new format.
The user normally edits through TUI/other application entrances and sees little readability
difference between the syntax candidates. Manual readability/editing comfort is secondary,
not a selection gate. Prioritize equal-operation save/correction costs, memory, backup growth,
recovery/migration and implementation/maintenance. Keep diagnostics/portable reading; do not
confuse syntax with whole-image rewrite, physical layout or backup policy.
The user also requests a final comparison with LOAM's format: do not assume parser
maintenance is the only disadvantage. [Long-term storage study](LONG_TERM_STORAGE_STUDY.ja.md)
owns current-path costs, limits and physical selection conditions.
`./tools/storage-study` measures existing native owners in fresh ignored scratch; it adds no
backend or dependency. Current-path baseline and monolithic save-phase decomposition are
complete; `./tools/storage-breakdown` observes only fresh synthetic source copies with an
original-owner control. Costs/limits and the next focused candidates live in the storage
study, not this handoff. Schema completeness, bounded retention, equal-operation append,
P7 and complete/off-host restore remain open.
Do not adopt a production format, prune any existing evidence or change LOAM originals.

## UI context

Reproduce LOAM's appearance and usability in Bakhlo. The target is Calendar Home
with Day / Month / Year, hierarchical Commands, and matching entry points,
navigation, confirmation, cancellation and return behavior for shared capabilities:
recording, Actual, Scheduled, Balances and Daily Pace. Build the new UI in English
with LOAM's labels first. Japanese UI is undecided. Implement Bonsai first;
a later Notty implementation remains an option, not an excluded frontend.
The English foundation is connected; full LOAM parity remains a target.
Home and basic Record / Preview polish have reached a verified checkpoint.
The earlier approved comparison slice provides stopped LOAM refresh into separate private
copies, short Bakhlo/LOAM launch commands, and direct root-palette theme selection.
These remain available; the current storage investigation does not authorize cutover
or expansion into accounting features.
The usage inventory used a separate verified fresh stopped capture. It did not update
comparison CURRENT or any prior writable trial. A selected comparison capture exists,
but its currentness/full compatibility has not been requalified here; inventory success
is not a successful fresh paired-UI conversion or operational cutover.
Home uses nearby/side-by-side Detail and a compact Calendar; Record floats while
retaining the parent date, with full-screen tiny input, border-only semantic colors
and explicit caret cell metadata. Tiny overflowing previews refuse publication;
ordinary paged previews require the final viewport before selected Publish + Enter.
Consult
LOAM's research on the limits of sharing before choosing reusable components;
do not assume every editing screen should be shared. Read [UI_DIRECTION.ja.md](UI_DIRECTION.ja.md) for the scope and rules,
including quiet terminal-owned colors, thin rounded frames, focused selection,
stable geometry, contextual bottom operations and wrapping feedback.

Bakhlo is not yet used as the operational household ledger. Old UI layouts,
themes and unused helpers may be replaced or deleted without compatibility.
Calendar Home is selected. Preserve Bakhlo's accounting contracts; this UI work
does not restore budgets, authorize new accounting assumptions, require LOAM's
entire accounting feature set, or introduce a new frontend framework.
Calculator input UX-3 remains designed but deferred.

Scope lesson: “LOAM-compatible UI” means its appearance and interaction, including
the Home structure and navigation; do not reduce it to styling or treat English
labels as an optional translation of the old Japanese UI.

## Authority and private data

- LOAM remains the operational authority; normal recording and its original
  household/config files stay there. No cutover, write, recovery, synchronization,
  reconstruction or migration of those originals is authorized by UI work.
- The earlier approved read-only capture and Bakhlo-native candidate are separate
  from cutover. Corrected entries may omit correction chains, but exact currency
  quantities, actual refunds/reversals, quantity support and plan-payment links
  must not be guessed or discarded.
- The private trial `scratch/daily-ui/household.sexp` and earlier candidate
  `scratch/daily_book_candidate_v1/household.sexp` exist. UI work/tests use
  synthetic copies instead. Do not put private contents, counts, screenshots
  or logs into fixtures, commits or public output.
- New approval also covers bounded read-only inventory of retained operation
  evidence in LOAM canonical history, using fresh stopped captures and stability
  checks. Preserve old captures/trials; do not read the live originals while LOAM
  is running or silently substitute older evidence. Unknown/imported/current-only
  evidence is not a full count of user actions. No private counts in public docs.
- Private inputs/results remain ignored, with restrictive permissions. Do not
  copy LOAM implementation source, install dependencies or adopt a production
  storage/UI entrance by implication.

## Current implementation

- `lib/` and `application/` contain the neutral exact-quantity/admission/query
  engine. Accounting calculations remain pure; terminal and filesystem effects
  stay outside it. Normal builds are Lean-free.
- The ordinary `bakhlo 1/2/3 ordinary-quantity` Book and `record`/`exchange`
  CLI are separate from Daily_book. v3 Book records explicit two-Measure
  exchanges; it does not represent all Daily plans or LOAM household families.
- `sexp/daily_book.mli` owns Daily's current contract: corrected entries,
  explicit plans and independent quantity support; reads monolithic v1..v3
  and Records v1, writes monolithic v3. Experimental budget allocation/routing
  APIs and trial v4 support were removed. Old budget-only trials may be recreated.
- Ordinary same-Measure recording, multi-posting drafts, date/amount/memo edits,
  browsing, admitted-Locus candidates, transaction preview and explicit plan
  payment are connected to the trial UI. Editing preserves stable IDs, posting
  structure/keys and payment links; unsupported Exchange/Reversal-related edits
  refuse instead of dropping their relationships.
  Replacement and Scheduled completion publication are supported by the monolithic
  path only. Records refuses both before append because its protocol cannot persist
  the replacement/completion link atomically; it must not append a partial Actual.
- Pure `put_plan`/`cancel_plan` support explicit occurrence create/update/cancel.
  Paid/cancelled plans cannot be edited or paid again; cancellation retains
  the occurrence and does not change physical quantities. Lifecycle controls
  beyond payment remain unconnected to UI.
- `daily_pace` computes an explicit one-Measure balance pool less open-plan net
  drains before a supplied exclusive end, divided by remaining calendar days.
  It is not spending permission, budget residual, historical replay, proof of
  complete plans or fresh balances. The current Daily Pace screen shows the supplied
  configuration, exact current quantities and deductions; configuration editing
  and historical Trend remain unconnected.
- Exchange input in Daily UI, settlement/reimbursement correspondence, balance
  observation updates, Attention and broader reports remain incomplete. Add
  only operations selected for actual household needs.

## UI and direct owners

`./ui --refresh` uses the existing private Daily conversion trial after LOAM is
closed, retaining exact household/config inputs, a fresh supported Daily v3 book,
a private entry/plan delta, and previous captures under `scratch/loam-comparison`.
It does not date-filter/append blindly, merge trial edits, or update originals.
Unsupported Actual/profile data and changed acquisition refuse without advancing
CURRENT. This local helper needs the earlier ignored converter; it is not full
household migration, live capture, complete backup or canonical-store adoption.
`./ui` opens the selected Bakhlo trial copy; `./ui loam` opens a separate LOAM trial
copy of the same capture using the already-built executable, never building LOAM
or falling back to live originals. UI theme settings are isolated in `ui-config`.
`./ui --demo` retains the synthetic preview. `./tools/tui` remains the explicit
selected-file Bonsai entrance. The old standalone Notty frontend,
paired UI benchmark and old Bonsai layout lab are removed. Notty remains a
transitive rendering library used by native renderer checks; dependencies have
not been removed or installed. This is the current implementation, not a permanent
Bonsai-only product decision; a new Notty renderer may follow.

Home is Calendar with Day / Month / Year and a period Detail region. Commands is
hierarchical. Actual, current-open Scheduled, Selected Day, Balances and current
Daily Pace use English labels. The Calendar counts Actual and open Scheduled;
role-aware income/expense totals remain unavailable because roles are not supplied.
Full Series management, Attention, historical Trend and Japanese switching are
not implemented. Theme offers Terminal (default, terminal-owned background/text
and ANSI colors including editor borders) and original Bakhlo Light / Dark
(fixed xterm 256 colors). Commands > Theme (also under Household setup) previews
with j/k or arrows, cancels to the exact parent menu with Esc/q, and saves UI-only
settings with Enter for the next
launch. Drafts, navigation and safety warnings are retained; failed settings saves
are session-only and reported. LOAM's dim styling remains a Bonsai API limitation.
Recording uses one transient Record model with Description,
Measure and signed postings. Esc/Cancel retain the draft; Preview offers Publish,
Edit and Cancel. Only Enter on selected Publish uses the existing publisher;
Ctrl-S opens a preview and never confirms publication.

- `daily_actions.ml`: draft/transaction conversion, validation, commit/reload.
- `daily_calendar.ml` / `ui_workspace.ml` / `ui_commands.ml`: Gregorian navigation,
  workspace selection and hierarchical Commands.
- `record_session.ml` / `daily_form.ml`: one Record draft/preview and UTF-8 caret helpers.
- `daily_overlays.ml` / `ui_text.ml`: terminal geometry, details and message catalog entrance.
- `daily_interaction.ml`: shared state, keys, focus and presentation.
- `daily_file.ml`: selected-file I/O/publication/recovery integration.
- `bonsai_daily.ml`: terminal rendering and event adapter.

Keep unknown versus zero, currency separation, complete quantities, draft
retention and visible conflict/uncertainty errors. Modal input/paste must not
reach the background or silently publish. Tiny preview panes must refuse
confirmation rather than hide required evidence. See [tui/README](../tui/README.md)
for current keys and recovery commands.

## Storage and unresolved safety

Monolithic publication performs full admission/printer checks, cooperative writer
locking, expected-base comparisons, synced attempt/pending/pre-edit backup writes,
selected rename and readback. Remaining/malformed/nonregular attempt/pending
artifacts or unavailable artifact inspection freeze writes across restart/reset/
reload; no automatic retry, adoption or backup pruning. Explicit acknowledgement
is limited to a candidate exactly matching the selected file now and does not
prove the outcome of an earlier publication. Restore-copy uses a fresh path;
copy success does not select a new operational ledger.

Records uses the existing append engine, request tokens and LSN checks instead
of monolithic attempt/pending files. Opening Records can recover a torn final
write; corruption refuses. Scheduled completion and replacement of an existing
Actual are refused before append; their bytes and cold state remain unchanged.
Do not describe every open/recovery operation as
read-only. Persistent client acknowledgement after restart/Ack loss (P7) remains
an independent unresolved safety boundary; monolithic recovery is not its proof.

Stable parent namespaces and cooperative writers are assumptions. Process-kill
tests do not certify power loss, media failure, hostile/noncooperative writers
or a fresh-host recovery environment. Backup retention, separate-media copies,
and reconciliation/adoption of differing or unreadable candidates remain undecided.
Full-before backups accumulate; whole-file admission/publication retains linear
costs. UI completion is not durable-store qualification or cutover approval.

## Verify and continue

Use the existing isolated tools; do not change global environments or use Python:

```sh
./tools/check
./tools/tui --self-check
./tools/compare self-check
./tools/tui --copy-from examples/daily-book.sexp --book scratch/FRESH_TRIAL/book.sexp
./tools/tui --book scratch/FRESH_TRIAL/book.sexp
```

Create a fresh ignored trial directory first; never overwrite a previous trial.
The launcher installs nothing, refuses unavailable isolated environments, and
`--self-check` runs shared contract checks and the native Bonsai renderer checks.

For current storage work use `./tools/storage-study` (or `100` for a short check),
the current study's narrow selection conditions and existing recovery/refusal tests.
Keep its measurements out of this handoff; do not start a new backend by implication.

When UI work resumes, review its exact diff and compare the resulting screens
and supported-operation key flows with current LOAM. Check relevant synthetic
cases: normal/compact geometry, Japanese/long text/huge amounts, empty/unknown
states, focus/viewport, resize, cancel, confirm, reopen and terminal restoration.
Use `tui/record_session_checks.ml`, `daily_interaction_checks.ml`,
`recovery_checks.ml` and the nearest `test/` owner for concrete boundaries.

[VERIFICATION.md](VERIFICATION.md) owns historical qualification and limits;
[CAPABILITY_LEDGER.ja.md](CAPABILITY_LEDGER.ja.md) is a wider capability/evidence
index, whose current claims must be checked against source. Git retains obsolete
UI roadmaps, budget experiments and milestone history. [AGENTS.md](../AGENTS.md)
owns standing development/data rules; the [cutover checklist](CUTOVER_CHECKLIST.ja.md)
does not authorize cutover merely because a trial UI works.
