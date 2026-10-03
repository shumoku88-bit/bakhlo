# Verification and assurance strategy

Status: PROPOSED overall strategy. Domain/application and CLI build/tests pass
locally: 86 expect tests, 10,000 generated cases each for Quantity, Movement,
application replay, zero-origin/current-assertion projections, Event identity/endpoint
closure, frontier, root lineages, reflected-root cuts and multi-group ownership,
plus three cram suites (100,000 actual generated cases across ten seeds).
Seeds: `loam-quantity-v1`, `loam-movement-v1`, `loam-application-v1`,
`loam-zero-origin-v1`, `loam-correction-endpoints-v1`, `loam-correction-frontier-v1`,
`loam-root-lineage-v1`, `loam-reflected-root-cut-v1`, `loam-current-quantity-v1`,
`loam-current-groups-v1`.
Nine optional Lean specification laws have been checked; no formal graph-to-row
or OCaml refinement proof. Platform coverage remains macOS x86_64.

## Evidence hierarchy is not a single ladder

| Evidence | What it can establish | Important limit |
| --- | --- | --- |
| OCaml types and abstract modules | Exclusion of selected invalid compositions/constructions | Not all semantic laws; unsafe operations and implementation bugs remain relevant |
| Unit / expect tests | Concrete executable behavior and readable examples | Finite examples, not universal laws |
| Property-based tests | Generated cases and shrinkable counterexamples | Depends on generators, oracles, and tested scope |
| Differential tests | Agreement with a reference on compared observations | Reference may be wrong; agreement is not a refinement proof |
| Alloy | Structural counterexamples / bounded exploration | State scope is bounded |
| TLA+ / TLC | Transition histories in the selected model and bounds | Requires correspondence to implementation and stated failure assumptions |
| Lean or another proof system | The stated theorem under its assumptions | Does not prove separately handwritten OCaml code automatically |
| Fault injection and recovery tests | Observed implementation behavior at selected failure points | Must distinguish process crash, I/O failure, and power loss |
| Benchmarks | Cost on a named workload and environment | Not a semantic or universal performance guarantee |

Use the smallest set answering a distinct gap: new semantics/failure boundaries
need stronger evidence; ordinary consumers need focused tests of their connection.
Reuse independent models/oracles, not a fresh verification bundle per slice.
Logical tiers: fast examples/boundaries for edits; extended exploration/properties
before semantic checkpoints; optional formal checks when artifacts/assumptions/mapping
change. `tools/check` still runs the full OCaml suite; no new tier machinery yet.
Formal tools remain development-only, never product build/test/release dependencies.

## Instrument review gate

Status: **ACCEPTED review policy** (D21), explicitly requested by the user so
successor pits do not forget the LOAM instruments. The wider assurance strategy
and individual tool adoptions are not thereby approved. This is a required review
step, not an all-tools execution pipeline or a machine-enforced semantic gate.

Before non-trivial design/implementation, and again when its assumptions or nearest
semantic neighbors change:

1. Name the observable question and invariant owner; separate D/P/R obligations.
2. Consult [semantic commitments](SEMANTIC_CONTRACT.md) and the narrow
   [reference/evidence map](REFERENCES.md) before repeating upstream work.
3. Identify what current types, tests, source inspection, and prior evidence can
   and cannot answer. Compile success is not evidence of correct household meaning;
   generated/bounded success is not a universal law.
4. Choose the smallest instrument set answering distinct residual questions.
   Record relevant choices or deferrals in the slice contract/task note **before
   implementation**. A few lines suffice; no new ADR or separate file per tool.
5. After work, record actual results/limits and carry unresolved revisit triggers
   into [handoff](HANDOFF.md). Reopen when the named trigger occurs; do not keep
   copying "deferred" without reviewing the changed question.

### Choose by question

| Question / trigger | Candidate instrument | Boundary |
| --- | --- | --- |
| Which meaning/evidence must survive? What is already known? | Semantic contract, reference/Evidence Atlas, D/P/R scaffold | Use now; these structure reasoning, not machine-check implementation |
| Is execution/refusal/ownership order hard to inspect? | DRAKON | Use for procedure, not topology or UI design; a small explicit function may suffice |
| Is dependency/authority topology hard to inspect? | D2 / dependency DAG | Use for structure, not an automatic second picture of the same procedure |
| Can a small structural counterexample distinguish competing representations or policies? | Alloy / explicit finite enumeration | State bounds/assumptions; neither proves unrestricted correctness |
| Is a general law important enough to retain beyond bounded cases? | Lean / a scoped proof artifact | Name statement, assumptions, implementation mapping and gap; never infer OCaml correctness from upstream proof |
| Do retry, ownership, crash/recovery, or operation ordering affect allowed outcomes? | TLA+ / TLC; SPIN for concrete process interleavings | Select when an actual transition/failure contract exists; state scheduling/failure bounds |
| Are reachability, dependency drift, duplication, or hygiene uncertain? | Focused repository audit | Adapt to OCaml/Dune only for a named question; Lean scripts are not portable verdicts |
| Is performance, scale, or recovery behavior the residual question? | Benchmark / fault injection | Use synthetic workload and named environment/failure points, not theorem surrogates |
| Is proof-checker independence itself the residual question? | Comparator / Nanoda or scoped checker audit | Not baseline OCaml infrastructure; requires a concrete retained proof question |

Types, expect tests, property tests, and external-client counterexamples remain the
fast implementation feedback loop. They complement these instruments; they do not
silently retire them. An additional view/tool must add a distinct answer, not a logo.

### Minimal review record

Use this in the relevant slice/task note, not a global transcript:

```text
Instrument review
Question / invariant owner:
D/P evidence already available:
Residual gap and claimed assurance scope:
Relevant instruments: use / defer / not applicable, with reason:
Revisit trigger (concrete capability or assumption change):
Execution/evidence: planned / not run / observed result, bounds and reproduction:
Model-to-OCaml correspondence and remaining gap (if applicable):
```

A needed but unavailable check is a named limitation/blocker; do not label it
covered or passed. Selected/planned is not run. Existing unperformed work must
not be retroactively labeled reviewed/proved. Unrelated tools need no boilerplate
entry; meaningful deferrals must explain **why now** and **when to reconsider**.

VR-01–VR-04 root/terminal, cut, one-group quantity and multi-group ownership reviews
are complete within slice scopes. Before full Actual/support-family composition,
VR-05's bounded base-validity/exact-support preview is reviewed in `HANDOFF.md`;
broader Actual/support-family admission remains OPEN.
Before storage/publication, revisit transition/failure instruments separately.
No indefinite blanket "later" decision.

Tool selection does not authorize installation, new dependencies, CI jobs, source
reuse, or scope expansion. Follow existing approval/provenance rules; record/pin
versions for any adopted experiment. Formal tools remain development instruments:
normal production build/test/release must not require Lean. Do not turn upstream
reference artifacts into a permanent duplicate production engine.

## First properties to consider

Select these per slice, not as a demand to implement the whole domain at once:

- Exact arithmetic remains exact beyond machine and JavaScript integer ranges.
- Ordinary single-Measure Movement admission enforces conservation and rejects
  practical invalid cases separately from the mathematical zero-total law.
- Correction preserves required provenance and follows the chosen currentness
  relation; ambiguous/invalid frontiers are not silently accepted.
- Projection does not mutate canonical evidence or turn missing support into zero.
- Encode/decode preserves admitted evidence according to a named equality
  (semantic equivalence and byte identity are different claims).
- Optimized computation agrees with a small transparent reference algorithm.
- Retry/competing-writer behavior follows the chosen operation contract.
- Publication/recovery exposes only allowed states under specified failures.
- Unsupported storage versions and malformed inputs fail explicitly.

Do not import a broad theorem into an unrelated operation by name alone.

## Current executable seams

- `movement_tests.ml` checks the validation predicate against a direct Zarith
  oracle, preserves input representation, and exercises perturbation/negation.
- `application_tests.ml` submits typed commands without argv, checks structured
  values, deterministic replay, preserved domain results/refusals, and immutable
  answers under repeated text projection/independent client ordering.
- `zero_origin_tests.ml` separates independent origin support from activity/zero
  net change, checks exact coordinate keys, duplicates, multiple Measures, signed/
  huge quantities, representation, and repeated/reordered queries. A direct Zarith
  oracle sums original Effects, independently of the index. These are conditional
  quantities, not current/historical balance admission; see [contract](BALANCE_SLICE.md).
- `correction_tests.ml` preserves general anonymous Event shapes and immutable
  source order, refuses duplicate identities, checks exact-token lookup against a
  source-list oracle, replays/reorders endpoint resolution, and verifies ordered
  missing roles/identities. Self/cyclic/competing raw edges demonstrate closure
  without currentness; see [contract](CORRECTION_ENDPOINT_SLICE.md).
- `frontier_tests.ml` checks disjoint-path admission against an independent
  list/fuel graph oracle, source/payload retention, order-independent membership,
  missing/duplicate diagnostics, actual cycle witnesses, and a 10,000-node chain
  plus its cycle. All 512 three-Event directed graphs are exhaustively checked;
  that scope excludes larger graphs, duplicate parallel edges, and absent IDs,
  which separate fixtures/generated cases address without universal claims.
  See [contract](CORRECTION_FRONTIER_SLICE.md); no household authority is inferred.
- `fixtures.ml` holds shared test constructors/assertions; `source_oracle.ml` retains
  original-list/fuel selection and direct Zarith arithmetic, independent of production
  indexes. Test-case modules do not supply helpers to other test-case modules.
- `lineage_model.ml` is a test-only immutable integer-relation transitive-closure
  model, independent of production IDs/maps/successor traversal. Two model tests
  explore all 65,536 four-node simple graphs and root/terminal partition properties.
  `lineage_tests.ml` compares the actual constructor/associations with that model,
  checks independent source-list generated oracles, tail extension versus prefix
  re-rooting, payload retention, order/replay, and a 10,000-node chain. See
  [pre-implementation selection and correspondence](ROOT_LINEAGE_SLICE.md).
  Enumeration is bounded and excludes absent nodes/parallel edges, separately
  covered by specimens; no unrestricted implementation proof is claimed.
- `root_cut_model.ml` adds original-prefix/list declaration admission to that
  independent graph model. One model and eight implementation expect tests compare
  all 1,168 admitted-four-node-relation/represented-subset cases (304 valid cuts)
  plus selected fresh-tail extensions. Source-list generated tests verify payloads,
  duplicate/unknown/non-root refusals, source binding, explicit rebinding after
  prefix/source changes, representation order and replay. See [contract](ROOT_CUT_SLICE.md).
- `formal/RootCutLaws.lean` optionally proves row-selection/terminal-update
  commutation, empty cut and composition for arbitrary finite rows, not graph
  admission or OCaml refinement. Installed Lean 4.33.1 was used with warnings fatal;
  Three later signed-delta/answerability laws cover unsupported assertions,
  assertion translation and reflected contribution noninterference, not Zarith/Base
  refinement. [Axioms, reproduction and trusted boundaries](../formal/README.md). Product checks
  do not invoke it; normal checks passed with an explicitly nonexistent `LEAN`.
- `current_quantity_tests.ml` checks one group's assertion admission, typed unknown,
  exact signed/huge coordinate-local decomposition and source retention. All 4,864
  four-node graph/admissible-cut/support subsets agree with independent closure/cut
  and original-Effect Zarith arithmetic; generated source-list cases verify duplicates,
  translations, replay/permutation and reflected/unreflected fresh-tail seams. The
  private arithmetic extraction preserves earlier zero-origin/CLI evidence.
  See [one-group scope and qualification](CURRENT_QUANTITY_SLICE.md).
- `current_groups_model_tests.ml` ran BEFORE product code: 256 ownership/cut cases
  (144 admitted), 2,304 updates/replays preserve whole assertion/cut premises.
  `current_groups_tests.ml` compares all those seams plus ordered root/local/global
  refusals, one-source rebinding, empty-group semantics, old-image retention and
  10,000 generated list/closure/original-Effect Zarith cases. Three optional Lean
  functional lookup laws were checked before code: incoming whole premise wins,
  unrelated premise survives, and lookup-idempotence. Not group/index/OCaml
  refinement or operational retry; see [contract](CURRENT_GROUPS_SLICE.md).
- `actual_source_tests.ml` checks the ordinary anonymous/base-validity Actual subset:
  625 four-Effect/two-Measure signed/huge predicate cases (16 admitted), empty/mixed
  Events, superseded physical refusal, cross-Measure cancellation, source/date/edge
  retention. Independent original-value Zarith oracle; legacy preview remains general.
  Public compiler clients distinguish that preview from the stronger source. Base
  validity admission was extracted once; existing date/reference tests still apply.
  This is not keyed/full normalized admission or factual/historical completeness.
- `actual_fixture_tests.ml` adds six focused boundary tests: unique/closed/complete
  base validity, 19 calendar/lexical specimens, exact neutral Effect decoding,
  malformed/unsupported/truncated inputs, retained source and independent group cuts,
  original-Effect arithmetic, unknown versus known zero, and honest read failures.
  `cli.t` exercises the real file-to-query path, exit/stream separation and unchanged
  fixture bytes; a public client distinguishes frontier from Actual preview.
  Reuses existing oracles; no new property campaign/model/theorem. Not normalized
  household admission, calendar-history completeness or arbitrary-file corruption detection.
- `command_tests.ml` preserves existing golden output while the CLI becomes an
  application client; it checks exact previews, syntax/refusal separation, stream
  choice, and escaped opaque input.
- `cli.t` runs the real executable with exit/stream checks, not only a mock adapter.
- `type_boundaries.t` compiles valid domain and application-only clients, then
  checks role mixups (Measure/Locus/Event), forged Movement/preview/conditional
  quantity, inconsistent Event memory, forged closed endpoint/frontier answers,
  forged lineage/cut/current group/answer/global image, separately-bound group
  composition, wrong source values and public access
  to the private aggregate. The curated Application root exports only public
  operations; specimens supply its generated intermediary CMI. It
  checks diagnostic content as well as failure status to avoid accepting unrelated
  compiler errors.
- `compiler_policy.t` copies actual root configuration into a language-only
  fixture, builds explicit complete controls, and rejects four counterexamples
  in dev/release: non-exhaustive/redundant matches, omitted record-pattern fields,
  and implicitly discarded typed results. Diagnostics and exit status are checked;
  this is not a general purity checker. See [engineering style](ENGINEERING_STYLE.md).
- A clean domain/application-only build was checked to leave presentation/CLI
  library artifacts unbuilt. Current application/presentation source has no
  hidden I/O/time/randomness; no UI package is required.

These do not establish household policy admission, storage, operational correction
application, TUI interaction, large-history latency, or protection against unsafe operations
such as `Obj.magic`. Synthetic fixture loading/base validity now exist, but no
full Actual history/admission or support-family routing. The supplied-Movement
projection still establishes neither temporal completeness nor correction selection.
Optional laws were not rerun for this artifact-unchanged composition checkpoint.

## Connecting models to code

Every retained formal result should record:

1. The property and why the product needs it.
2. State/input mapping and correspondence to implementation owners.
3. Assumptions, bounds, trusted code/tools, and excluded failures.
4. How to reproduce the check with a pinned tool environment.
5. Executable specimens guarding representative model/code seams.
6. Which changes require requalification.

If code changes invalidate that mapping, update/requalify the artifact or clearly
withdraw the guarantee. Never display a historic green proof as current coverage.

## CI direction

`./tools/bootstrap` sets up the isolated locked baseline; `./tools/check` runs
build and forced tests. See `DEVELOPMENT.md` for exact commands and guarantee limits.
Formatting/static-check tooling and the wider supported compiler/platform matrix
still need qualification. Dependency changes require reviewed lock updates.

Separate fast deterministic product checks from costlier model exploration,
stress tests, and benchmarks. Failure of an explicitly release-required guarantee
still needs resolution; an optional tooling job is not an excuse to hide it.
Do not make a Lean installation necessary for ordinary OCaml build/test/release.

Fixtures and diagnostics must not leak private household content. Specify random
seeds/reproduction commands and retain minimized failing specimens where useful.

## Portfolio evidence

Prefer two or three complete case studies to a catalog of tool logos:

```text
concrete question -> alternative designs -> counterexample or law
-> implementation boundary -> executable checks -> limits -> decision
```

Disclose AI assistance honestly. Distinguish human decisions, generated artifacts,
reviewed implementation, and machine-checked evidence without inventing provenance.
