# Handoff — supplied disjoint-path correction frontier; no Actual adoption

Updated: 2026-10-02.

## User intent and current stop point

The user requests continued professional-quality OCaml development, aspiring to
Jane Street-associated engineering quality. Do not repeat an earlier conversational
claim that this small core is production-certified, universally pure, exhaustively
tested, or guaranteed reproducible on every host. Quality is an aspiration backed
by named evidence; important operational capabilities remain absent.

Current UI scope still excludes TUI/web/dashboard/component implementation and
speculative UI states/frameworks/OxCaml. No UI, storage bindings, cache, clock, or
incremental framework was introduced. Endpoint closure is complete; the later
`CORRECTION_FRONTIER_SLICE.md` now qualifies a whole supplied relation as closed,
unique-target/unique-replacement, and acyclic. It materializes terminals/untouched
Events while retaining sources. This conditional frontier is **not** a current
Actual image, root-cut witness, correction publication, or temporal completeness.

Initial accepted scope (ADR 0001) need not be asked again:

- Local single user; macOS/Linux, CLI first, eventual TUI; GUI/Web deferred.
- No initial public access, multi-user product, or synchronization.
- Synthetic development; existing LOAM remains operational authority. No dual writes.
- Runtime Base + Zarith; tests ppx_expect + Base_quickcheck. Every additional library
  needs a concrete capability and named consumer; none was added this turn.
- Isolated opam baseline is established (ADR 0002). No global environment changes.
- User authorized initial commit and private GitHub hosting. Public publication,
  license selection, upstream copying, and operational migration remain unapproved.

## Standing instrument review and next open trigger

The user explicitly requested repository memory for the LOAM tools. D21 now
requires the [instrument review gate](VERIFICATION.md#instrument-review-gate)
before non-trivial work; `AGENTS.md` and `CONTRIBUTING.md` point to it. Record
relevant use/deferral reasons and concrete revisit triggers in each slice/task
note. Do not assume OCaml types/tests replace semantic maps, D/P/R, DRAKON/D2,
Alloy, Lean, transition models, or focused audits. No all-tools pipeline or newly
installed tool is implied. This documentation change ran no formal tool.

**VR-01 — OPEN; review before root-to-terminal or reflected-root-cut code.**

- Question: under the qualified disjoint-path relation, does root identity and
  whole-lineage exclusion survive later corrections without dropping independent
  provenance or reintroducing an already reflected occurrence?
- Prior evidence: frontier contract/tests and narrow upstream root-cut references;
  these do not establish an OCaml root/cut operation, which is not implemented.
- Review candidates: structural counterexamples via Alloy or finite enumeration;
  a scoped Lean law if unrestricted root/terminal uniqueness or exclusion stability
  earns retention. Check existing evidence before creating a duplicate model.
- Required next action: record the chosen distinct question, tool/use-or-deferral
  reason, scope, implementation mapping/gap, and acceptance checks **before coding**.
  This is a review obligation, not a preselected tool or a claim of completed proof.
- Next separate trigger: defining storage/publication retry/crash/ownership behavior
  reopens TLA+/TLC or SPIN/fault-injection selection. Neither is current coverage.

## Implemented interfaces

Existing contracts remain in `QUANTITY_SLICE.md`, `MOVEMENT_SLICE.md`, and
`BALANCE_SLICE.md`; no existing CLI output/exit semantics were changed.

- `Quantity`: abstract exact signed quanta, independent of Measure.
- `Identifier.Measure`/`Locus`: distinct nonempty opaque identities, exact spelling.
- `Effect`: neutral signed anonymous change; zero can exist before Movement checks.
- `Movement`: abstract nonempty/nonzero/single-Measure/conserving ordinary movement;
  ordered structured refusals, preserved representation, no mixed-Measure sum.
- `Effect_coordinate` and `Zero_origin_coverage`: typed coordinate and explicit
  independent support set; missing support is not zero, duplicate support refused.
- `Movement_check`: pure typed operation and abstract structured preview; existing
  positive aggregate is materialized once, not computed by formatting.
- `Zero_origin_projection`: immutable coordinate index over supplied Movements;
  conditional quantity or `Origin_unknown`, not current/historical Actual,
  completeness, correction selection, or purchasing power. No renderer/CLI added.
- **New `Identifier.Event`**: distinct caller-supplied identity, nonempty/exact,
  mechanical comparator for Base Map, no chronology/kind/revision rank.
- **New `Event`**: identity plus retained anonymous neutral Effects. Empty, zero,
  mixed-Measure, and nonconserving observations remain representable: Event is not
  Movement. Keyed Effects/independent external metadata must not be erased to fit
  this subset; no real-data importer exists.
- **New `Event_memory`**: abstract retained list plus matching immutable ID index;
  first duplicate identity refused with original/repeated input positions, even
  for identical payloads. No latest-wins normalization or publisher retry policy.
- **New `Event_correction`**: raw target/replacement IDs, no existence/graph claim.
- **New `Correction_check`**: two indexed lookups in one memory, abstract `closed`
  retaining edge and both Events, or ordered/nonempty missing-endpoint errors.
  Self/cyclic/competing/merging edges can close without establishing authority.
- **New `Correction_frontier`**: abstract conditional disjoint-path success;
  retained Event memory, original correction list, and untargeted frontier Events
  in original Event order. Fail fast on unresolved edges or repeated endpoints,
  then reject cycles with an actual closed path witness. Identical repeated edges
  are refused, not deduplicated. No root-to-terminal/current-quantity query yet.
- `Movement_text`, `Movement_command`, `bin/main.ml`: pure text/argument seams and
  explicit argv/stream/exit shell. Preview says structurally valid (not recorded).

No production `ref`, mutable field, assignment, filesystem/process/time/randomness
is introduced in Domain/Application. Six test-only refs assert generated execution
counts. Root compiler policy preserves strict sequencing/fatal warnings 8/9/11 in
all profiles. Use ordinary values; no generic State/command bus or effect monad.

## Qualification of the current working tree

macOS x86_64; isolated OCaml 5.3.0 / Dune 3.24.2:

- `./tools/check`: PASSED (build plus forced tests).
- `dune runtest -p loam_ocaml --force`: PASSED; tests actually execute.
- `dune build @install`: PASSED for four internal libraries and executable.
- Clean `dune build --root . lib/loam_domain.cmxa application/loam_application.cmxa`:
  PASSED; presentation/CLI native libraries and CMIs remained unbuilt.
- **39 expect tests**: Quantity 3, Movement 4, application 4, zero-origin 6,
  correction endpoints 7, correction frontier 9, CLI 6.
- **60,000 generated cases**: 10,000 each with `loam-quantity-v1`,
  `loam-movement-v1`, `loam-application-v1`, `loam-zero-origin-v1`,
  `loam-correction-endpoints-v1`, `loam-correction-frontier-v1`;
  maximum 10,000 shrink attempts on failure,
  executed counts asserted. Finite cases are not universal laws or coverage metrics.
- New fixtures cover exact Event tokens, general observations versus Movement,
  equal/different-payload duplicate IDs, retained evidence/source order, both absent
  roles including one ID in both roles, and closed self/cycle/competition/merge
  without terminal selection. Generated memory/closure checks compare against an
  independent source-list lookup oracle, replay/reorder, and reject injected duplicates.
  Frontier tests reject branches/merges/cycles, check actual diagnostic witnesses,
  compare with an independent list/fuel oracle, exhaust all 512 three-Event graphs,
  and complete a 10,000-node chain/reversed chain/cycle. Enumeration is bounded,
  not a proof for arbitrary graphs. Initial test syntax/API mistakes were corrected
  against installed interfaces; no compiler checks were weakened.
- Three cram suites: real CLI output/exit/stream, external type boundaries, and
  dev/release compiler-policy positive/negative controls. New valid client needs
  only Domain/Application CMIs. New rejected cases: wrong Event identity role,
  inconsistent memory record, forged closed/frontier answers, and closed edge used
  as a graph-qualified frontier; diagnostic and status checked.
- Package inventory exactly matches all 50 locked versions; manifests/lock and
  toolchain unchanged. New index uses the already-approved Base capability.
- Links/fences across 21 documents, source whitespace (cram blank-output indentation
  excepted), test inventory, and shell syntax checked. Generated lock formatting
  retained; no private data/upstream code/global config was copied or changed.

These checks do not establish full household admission, corrected current Actual,
complete history, durability/recovery, terminal usability, latency/scale, formal
correctness, or cross-platform qualification. Linux/Apple Silicon remain targets.
Unsafe operations such as `Obj.magic` are outside abstract-interface protection.

`test/dune` uses private `loam_tests`, release-enabled inline tests, built-in cram.
Compiler boundary cases depend on internal Dune CMI paths; update deliberately.
Compiler-policy fixtures copy actual root configuration and check exact-reason
rejection with successful controls. Do not weaken source checks/diagnostics or
silently suppress the selected compiler policy.

## Reference and repository state

- Baseline commit is `45adb0c` (Initial commit). This checkpoint contains endpoint
  closure, conditional correction-frontier admission, and the D21 instrument-review
  policy. The user explicitly authorized committing and pushing this checkpoint to
  the existing private origin. Use `git status`, `git log`, and upstream/remote refs
  for live commit/push state; this checkpoint is not a release or operational cutover.
- Private GitHub `shumoku88-bit/loam-ocaml` was verified via `gh repo view` metadata
  (`isPrivate: true`). Hosting is not public release, licensing, or cutover.
- Existing LOAM checkout observed `80e50c7c20ee35d9d22ec95ff5e6626e1286ab82`;
  inspected Core Event/EventMemory/EventCorrection files are unchanged against
  earlier reference `180707c58647dc7cad3361458c1801be184d15af`. See `REFERENCES.md`.
  Existing repository remains clean; no upstream build or proof run was made.
- Standard entry points: `./tools/bootstrap`, `./tools/opam`, `./tools/check`.
  Opam 2.6.0, registry `ac27950e5eac6c981ad809dff370c937820b7893`, transitive lock.
  Earlier independent fresh-switch replay is historical evidence, not rerun here.
- Compiler/cache/install files are ignored; synthetic scratch is excluded from
  Dune as well as Git. Do not commit environments or private diagnostics.
- `-p` selects the Dune root already; do not combine with `--root`.
- Standard `Effect`/Base namespace shadowing and reserved lowercase `effect` need
  care. New code qualifies `Loam_domain`/Base collections explicitly.

## Next bounded engine work

Endpoint closure and conditional disjoint-path frontier admission are complete.
First resolve the OPEN VR-01 instrument review above; do not skip it because the
current compiler/tests pass. Then specify a stable-root-to-terminal query over
that qualified relation, if needed by one explicit current-anchor question. Preserve complete lineage and
original provenance; then separately qualify reflected-root cuts/origin support.
Do not relabel a supplied frontier current Actual without its selection/admission
contract. No ordinary Movement narrowing, occurrence dates, or completeness is
inferred from Event shape. Do not select by list order, token spelling, guessed
timestamps, or last-write-wins.

Current anchors additionally require reflected correction-root cuts, not merely
baseline amount plus later-dated Movements. No activity proves zero origin. Missing
or failed loading must never become an empty Event memory/projection basis.

No automatic UI implementation, wholesale Lean translation, generic framework,
cache, or index matrix follows from this slice. Measure a real workload before
performance claims. If introducing time-dependent meaning, pass explicit date
coordinates rather than reading global now.

Storage remains OPEN: compare atomicity, durability, recovery, backup/restore,
migration, diagnostics, and maintainer cost before adding bindings. Publication,
real-data migration, public release, or a UI need their separately scoped decisions.
Keep long-lived rules in charter/ADRs; exact slice laws/evidence in narrow contracts.
