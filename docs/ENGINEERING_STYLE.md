# Functional core and explicit edges

Status: current implementation review and compiler hardening, not certification
or a claim about Jane Street's internal standards. The user requested continuing
at that quality aspiration and checking that the engine is not written as a
mutable procedural workflow. The preparation-only UI scope remains in force.

## Review boundary and obligations

- D: inspect all handwritten `.ml`/`.mli` files in `lib/`, `application/`,
  `presentation/`, `cli/`, and `bin/`, plus property-test counters/build profiles.
  Domain/application records are immutable; there is no business `ref`, assignment,
  mutable field, hidden clock, randomness, process, or filesystem access.
- P: abstract admitted values, exact arithmetic, typed success/refusals, independent
  application clients, and deterministic executable checks already exist.
- R: prevent package/release builds from relaxing selected compiler checks, and
  make the replay oracle notice new refusal constructors/fields at compilation.

## What functional means here

- Domain computes values with `map`, `fold`, pattern matching, and immutable data.
  Application maps a typed command to a typed result; no dummy mutable State.
- CLI's recursive argument collector threads a new immutable accumulator and
  position. An ordered traversal is not mutation of shared business state.
- `Result.bind`/`let*` explicitly propagate parse refusal; sequencing dependencies
  does not make them effectful. `Printf.sprintf` constructs text, not output.
- `bin/main.ml` reads argv, writes streams, and exits. This is the imperative shell,
  not the accounting core. Test-only refs count executed generated cases so an
  accidentally skipped test cannot be reported as qualification.

Do not rewrite honest I/O as an ornamental monad or ban every loop/ref for image.
Prefer an immutable functional core. Any later local mutation needs a named owner,
observable contract, and concrete reason (an explicit effect/test boundary or
measured algorithmic need). Do not scatter state updates through business helpers.

## Compiler guardrails

The root `dune` configuration retains Dune's standard flags and, in **every
profile**, adds:

- `-strict-sequence`: the left side of `;` must have type unit. Accidentally dropping
  a validation `result` before returning another value becomes a type error.
- Fatal warning 8: non-exhaustive pattern matching.
- Fatal warning 9: omitted fields in record patterns.
- Fatal warning 11: redundant cases.

The inspected baseline development profile already had strict sequencing/fatal
checks; the release profile did not retain equivalent protection. These checks
must not disappear with `-p`/release. They are not a purity checker or proof that
all returned errors are handled: explicit `ignore`, `let _`, record-pattern `_`,
unsafe casts, and warning suppressions still require review.

Closed semantic variants should be handled deliberately. A catch-all is useful
for open argument strings or negative fixture predicates; it must not silently
absorb a new domain distinction. The application replay comparator now enumerates
its left-hand error constructors and destructures same-kind fields, so constructor
or field growth requires an explicit update instead of falling through `_`.

## Executable acceptance checks

`test/compiler_policy.t` copies the actual root configuration into an isolated
language-only fixture (not a synthetic household model). In dev and release it:

1. Builds an explicit, complete control, including deliberately ignored values.
2. Rejects a missing variant case, an omitted record-pattern field, a redundant
   case, and an implicitly discarded typed result.
3. Checks the failure diagnostic as well as exit status. Build a named library
   target, not an empty default alias that could falsely pass without compilation.

The fixture copy alone is made writable: Dune sandbox inputs may be read-only.
No project source, global compiler configuration, or dependency lock is changed
by a counterexample. `./tools/check`, package-mode tests, and install build cover
the actual product alongside these compiler specimens. A separate counterfactual
release build without the copied policy compiled all four specimens, confirming
that the rejection checks detect loss of the guards rather than unrelated errors.

## Limits and next work

The compiler checks protect selected composition/evolution mistakes. They do not
establish full semantics, universal purity, history latency, storage durability,
or interactive behavior. No new UI, framework, clock, cache, or external dependency
is justified by this review. The CLI remains validation-only. The later
[zero-origin slice](BALANCE_SLICE.md) adds conditional indexed arithmetic with
immutable Base Map/Set, not a mutable history cache or admitted Actual authority.
The [endpoint slice](CORRECTION_ENDPOINT_SLICE.md) adds immutable unique-ID memory
and a pure two-lookup correction check, retaining both observations without apply
or current-frontier selection. The later [frontier slice](CORRECTION_FRONTIER_SLICE.md)
checks a whole relation with persistent maps/sets and tail-recursive walks, then
materializes a conditional frontier while retaining source facts. Completed-node
sharing avoids restarting every path; no mutable flags or global state are added.
The later [lineage slice](ROOT_LINEAGE_SLICE.md) retains resolved replacement
observations in the transient index and walks each root path tail-recursively after
cycle checks. Abstract associations are materialized once; terminal getters do not
rebuild the relation, throw for an impossible lookup, or promote it to current Actual.
The [cut slice](ROOT_CUT_SLICE.md) adds one pure ordered declaration scan and filter,
consuming only qualified lineages. Maps/sets are transient; the immutable result
retains its original source and declarations. No mutable flags, I/O, graph rebuild,
quantity arithmetic, or global snapshot claim is introduced there.
The [one-group quantity slice](CURRENT_QUANTITY_SLICE.md) then gates exact
coordinate-local answers by independent assertions. Private Effect_sum is shared
with zero-origin arithmetic, never with its support meaning. Public namespace
exports are curated; logical aliases/explicit intermediary-CMI test dependencies
preserve clean builds without missing-CMI warning suppression. No query-time
recalculation or full Actual/current support-image claim is introduced.

Next functional capability still needs one real household question, minimal
qualified evidence, explicit inputs (including date coordinates when meaningful),
and typed answer/refusal/uncertainty. Do not invent a generic state machine or
translate every Lean feature merely to appear complete.
