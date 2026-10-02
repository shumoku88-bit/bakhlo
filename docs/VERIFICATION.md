# Verification and assurance strategy

Status: PROPOSED overall strategy. Domain/application and CLI build/tests pass
locally: 23 expect tests, 10,000 generated cases each for Quantity, Movement,
application replay, and conditional zero-origin projection, plus three cram suites.
Seeds: `loam-quantity-v1`, `loam-movement-v1`, `loam-application-v1`,
`loam-zero-origin-v1`.
No formal proofs have run in this repository; platform coverage is macOS x86_64.

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

Use the smallest set that answers distinct questions. Formal tools are development
instruments; consumers must not need them to run the product.

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
- `command_tests.ml` preserves existing golden output while the CLI becomes an
  application client; it checks exact previews, syntax/refusal separation, stream
  choice, and escaped opaque input.
- `cli.t` runs the real executable with exit/stream checks, not only a mock adapter.
- `type_boundaries.t` compiles valid domain and application-only clients, then
  checks rejection of swapped Measure/Locus roles (Effects and coordinates), a
  forged Movement, preview aggregate, and conditional quantity answer. It checks diagnostic content as well as failure
  status to avoid accepting unrelated compiler errors.
- `compiler_policy.t` copies actual root configuration into a language-only
  fixture, builds explicit complete controls, and rejects four counterexamples
  in dev/release: non-exhaustive/redundant matches, omitted record-pattern fields,
  and implicitly discarded typed results. Diagnostics and exit status are checked;
  this is not a general purity checker. See [engineering style](ENGINEERING_STYLE.md).
- A clean domain/application-only build was checked to leave presentation/CLI
  library artifacts unbuilt. Current application/presentation source has no
  hidden I/O/time/randomness; no UI package is required.

These do not establish household policy admission, storage, correction, TUI
interaction, large-history latency, or protection against unsafe operations
such as `Obj.magic`. There is no admitted Actual history/date/load operation yet;
the supplied-Movement projection does not establish temporal completeness or
correction selection. Do not invent coverage of those future capabilities.

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
