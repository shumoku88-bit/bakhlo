# Handoff — conditional zero-origin projection; no UI implementation

Updated: 2026-10-02.

## Current user instruction and stop point

The user asked to continue at the professional OCaml quality target and verify
that the code is functional rather than a mutable procedural workflow. The prior
scope still requires future-UI preparation **without building any UI now**;
interactive traces/screens/workbench remain superseded. Read `UI_DIRECTION.md`,
ADR 0003, and `ENGINEERING_STYLE.md`. Do not claim an official Jane Street standard,
certification, or affiliation.

No TUI, web UI, dashboard, components, speculative load/navigation/draft state,
UI dependency, OxCaml, clock abstraction, cache, or incremental framework was
introduced. After the user's authorization to continue engine work, a bounded
conditional zero-origin quantity projection is implemented. Read `BALANCE_SLICE.md`:
this is supplied-basis arithmetic, not admitted current Actual, historical
completeness, purchasing power, or an operational replacement.

Do not ask again about initial scope (ADR 0001):

- Local single user; no initial public access, multi-user product, or sync.
- macOS/Linux; CLI first, eventual practical UI TUI, GUI/Web only when needed.
- Synthetic data; existing LOAM stays authority until separately approved migration.
- Runtime Base + Zarith, test ppx_expect + Base_quickcheck.
- Every added library needs a concrete capability reason and named consumer.
  No Core/Async, storage bindings, or UI toolkit has been introduced.
- Isolated opam setup is approved and complete (ADR 0002).

## Implemented

Read [Movement slice](MOVEMENT_SLICE.md) for unchanged domain/CLI contracts.

- `lib/quantity.*`: abstract exact signed quanta.
- `lib/identifier.*`: distinct abstract Measure/Locus, nonempty opaque strings.
  Preserve exact spelling; no catalog/alias/locale authority. Adapters escape text.
- `lib/effect.*`: neutral Locus/Measure/Quantity; zero may exist before validation.
- `lib/effect_coordinate.*`: typed neutral Locus x Measure pair; exact spelling,
  mechanical lexicographic Base comparator, no chronology or valuation.
- `lib/zero_origin_coverage.*`: abstract finite independent declaration; empty
  supports nothing, first repeated coordinate is refused with its input position.
  Constructor checks shape, not truth of the declared origin premise.
- `lib/movement.*`: abstract validated ordinary Movement; nonempty/nonzero,
  one Measure, exact zero total. Ordered structured refusals. No mixed-Measure
  aggregation. Preserve represented order/multiplicity and same-Locus changes.
- `application/movement_check.*`: pure stateless typed command, abstract semantic
  preview, or unchanged domain refusals. Preview exposes Measure, represented
  Effects, and exact positive total materialized once per successful command.
  No formatting, implicit time, I/O, fake State, or publication capability.
- `application/zero_origin_projection.*`: pure immutable coordinate totals over
  supplied validated Movements, materialized once with existing Base Map/Set.
  Typed query returns an abstract conditional answer or `Origin_unknown`; no scan
  of the supplied basis per query. Never infer origin from activity or zero net
  change. No Actual/Scheduled selection, dates, correction-root cuts, I/O, or
  completeness/admission proof. No renderer/CLI adapter added for this question.
- `presentation/movement_text.*`: existing CLI text projection of the structured
  answer/refusals; no revalidation or aggregate recomputation.
- `cli/movement_command.*`: grammar/typed input parsing, application invocation,
  help/syntax errors, output/exit mapping. `Validated` now carries application
  preview, not bare domain Movement; no external stable-API promise exists.
- `bin/main.ml`: real `loam-ocaml` executable, argv/output/exit only.
- Root `dune`: strict sequencing and fatal warnings 8/9/11 in every profile;
  release/package mode no longer relaxes these selected checks.
- `test/compiler_policy.t`: actual-config controls/counterexamples in dev/release.
  The replay comparator enumerates error constructors and destructures fields,
  making new variants/fields require a deliberate update.

Review found no business refs, mutable fields, assignment, or hidden I/O/time/
randomness in the current handwritten Domain/Application. Recursive collection,
folds, `Result.bind`, and text construction are pure. I/O/exit is the intentional
imperative shell; four test-only refs count generated executions. Local mutation
is not categorically banned, but needs an owner and concrete justification.

Separate Dune libraries enforce inward source dependencies. Domain/application
build without presentation/CLI; future clients/tests call the typed operation
without argv or text parsing. These are internal boundaries, not new packages.

```sh
./tools/opam exec -- dune exec loam-ocaml -- check-movement \
  --effect wallet jpy -1000 --effect food jpy 600 --effect transport jpy 400
```

The preview says **structurally valid (not recorded)**. Raw exact quanta are not
inferred display units. No dates, catalog-approved Loci, Event identity, relations,
correction, household reads/writes, or persistence are implied. No-argument launch
refuses with usage; it does not pretend a TUI exists.

Exit codes remain 0 help/valid preview (stdout), 1 Movement refusal (stderr),
2 syntax refusal (stderr). Each Effect has its explicit Measure. Existing CLI
golden outputs and process assertions were preserved, not rewritten for the refactor.

## Current qualification

macOS x86_64, isolated OCaml 5.3.0 / Dune 3.24.2:

- `./tools/check`: PASSED (build and forced tests).
- Package-mode `dune runtest -p loam_ocaml --force`: PASSED; tests execute.
- `dune build @install`: PASSED for four libraries and executable.
- Clean `dune build --root . lib/loam_domain.cmxa application/loam_application.cmxa`:
  PASSED; presentation/CLI CMIs and native libraries remained unbuilt.
- 23 expect tests: Quantity 3, Movement 4, application 4, zero-origin 6, CLI 6.
- Generated checks: 10,000 each with `loam-quantity-v1`, `loam-movement-v1`,
  `loam-application-v1`, `loam-zero-origin-v1`; 10,000 maximum shrink attempts on
  failure, counts asserted.
  Application cases replay raw, paired, and foreign-Measure commands and compare
  typed fields/refusals against Domain; this is not an independent conservation proof.
- Application fixtures check huge split/repeated-Locus values, all four refusal
  variants/fields/order, repeated projection, and independent client ordering.
- `zero_origin_tests.ml`: keys preserve roles/exact spelling (including separator
  collisions), explicit support versus unknown/activity/net-zero, duplicate support,
  multi-Measure/negative/huge quantities, multiplicity/source preservation, replay/
  reorder/local coverage. Generated oracle sums original Effects directly in
  Zarith, independently of the coordinate index.
- Three cram suites. `test/cli.t`: real success/refusal, exact quantities,
  exit/stream assertions.
- `test/compiler_policy.t`: complete control builds in dev/release and four
  rejected specimens per profile, with exact-reason diagnostics: missing match
  case, omitted record-pattern field, redundant case, implicitly discarded result.
  Named library targets prevent empty-build false positives. Only the fixture's
  copied Dune input is made writable; real source is not modified by specimens.
  Separate policy-free release fixtures compiled all four bad specimens, confirming
  guard-loss sensitivity; temporary scratch fixtures were removed afterward.
- `test/type_boundaries.t`: valid domain/application-only clients compile;
  swapped Measure/Locus roles in Effects/coordinates and forged Movement, preview,
  and conditional quantity answer fail with expected diagnostics. Application-only client has no CLI/presentation CMI path.
- Installed inventory exactly matches all 50 locked package names/versions.
  Dependency manifests/lock, toolchain, existing Quantity/Movement semantics, and
  CLI behavior remain unchanged. New coordinate/support/projection consumers use
  already-approved Base; no new external dependency.
- Links/fences across 19 documents, source whitespace (cram blank-output
  indentation excepted), test inventory, and shell syntax: PASSED. Generated lock
  formatting was preserved, with package versions checked separately.
- No real data/upstream implementation copied or changed. Existing Lean repository
  remains clean; no global environment changes, formal-tool runs, or migration.

These checks do not establish operational admission, durability, terminal behavior,
accessibility, large-history latency, or universal formal correctness. Admitted
Actual histories, date/cycle/schedule reports, and loading are not implemented.
Conditional arithmetic is not current-balance admission.
Do not claim fake state/test coverage for them. Unsafe `Obj.magic` is outside
abstract-interface protection. Linux/Apple Silicon remain unqualified.

`test/dune` uses private `loam_tests` and built-in cram, no new test framework.
Inline tests are enabled in release profile. Type-boundary cram names internal
Dune CMI paths; update deliberately if build layout changes without weakening checks.
Compiler-policy cram depends on actual root `dune`; do not hardcode replacement
flags in specimens, weaken diagnostics, or silently suppress the new policy.
Current OCaml quotes type names in diagnostics; sequence checks allow quoting but
also require the specific left-hand-sequence reason.

## Environment and repository state

- `./tools/bootstrap`, `./tools/opam`, `./tools/check` are standard entry points.
- Fixed opam 2.6.0, registry `ac27950e5eac6c981ad809dff370c937820b7893`,
  and transitive lock. Read `DEVELOPMENT.md` / ADR 0002 for isolation limits.
- Earlier independent fresh-switch replay matched all 50 packages and passed
  Quantity checks. It was not rerun for this dependency-unchanged preparation.
- No license, remote, publication, or initial commit. All source remains untracked
  in initialized Git; do not clean/reset it away or manufacture attribution.
- Compiler/cache/build/install state is ignored. Synthetic experiments belong in
  `scratch/`, excluded from Dune discovery as well as Git.
- `-p` already selects the Dune root; do not combine it with `--root`.
- `Effect` is also a standard module; lowercase `effect` is reserved. Qualify
  domain references; `movement.ml` avoids Base's Effect shadowing.

## Next bounded work — engine semantics only until scope changes

The preparation stop point has been reached. Do not automatically select a toolkit,
write interaction traces/screens, or port every Lean feature. A future frontend is
optional to the useful, independently callable engine.

The completed question is quantity implied by supplied Movements plus independent
zero-origin evidence. Current anchors were deliberately not simplified into
baseline-plus-later-dated-Movements: upstream needs reflected correction-root cuts.
No raw timestamp or observed activity can supply that evidence.

Before an operational balance query, establish a minimal selected-current-Actual
input/admission/consistency contract. Do not pass failed or missing loading as an
empty projection basis. A pure synthetic admission slice can precede storage;
choose its exact scope/evidence before inventing Event/correction/date APIs.
For further engine work, identify one real question, minimal qualified synthetic
input, and typed success/refusal/uncertainty result.
Use narrow existing-LOAM evidence; preserve Actual/Scheduled, anchor/history,
amount/presence, valuation, and review distinctions where relevant. Only introduce
state transitions and explicit date coordinates when that operation requires them.
Keep canonical-input construction, semantic queries, read models, and formatting
separate; UI selection/focus/scroll must never drive business recomputation.

History scale is unmeasured: profile an actual future workload before deciding
indexing/caching/incremental mechanisms and their consistency scope. Never invent
hidden now, randomness, I/O, or empty-success defaults for incomplete evidence.

Storage remains OPEN. A separate text/SQLite comparison needs atomicity, durability,
recovery, backup/restore, migration, diagnostics, and maintainer cost before bindings.
Publication/correction/migration and UI implementation require their own scoped
work; a preview or a hypothetical button cannot authorize them.

Keep long-lived decisions in charter/ADRs; current contracts and qualification in
narrow documents/tests. Do not treat this handoff as approval of new product scope.
