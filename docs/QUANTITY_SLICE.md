# First implementation step — exact Quantity

Scope: a pure arithmetic building block, not a household engine or CLI.
Authority: user-approved initial stack and instruction to start development.

## Obligations

- D: existing semantic contract S3 requires signed unbounded integer quanta.
- P: original LOAM's exact arithmetic semantics are reference evidence only;
  no Lean proof transfers to this implementation.
- R: expose a small OCaml contract, implement it with Zarith, and exercise exact
  arithmetic beyond machine limits using examples and generated tests.

## Contract

`Loam_domain.Quantity.t` is abstract and immutable. Explicit conversion to/from
`Z.t` is lossless; no conversion to machine integers or floating point is offered.
Zero, addition, negation, subtraction, equality, ordering, and finite sums are
exact (subject to finite host resources, not fixed-width overflow).

Quantity is unit-neutral arithmetic. It does not carry a Measure or authorize
addition across household Measures. Later Movement/Effect admission must enforce
that boundary. Do not present this module as a complete monetary value type.

No parser, rounding policy, division, valuation, serialization format, clock,
identifier policy, storage, or UI is introduced in this step. Tests use decimal
text only to construct/display synthetic Zarith values, not a product wire format.

## Acceptance checks

- An explicit `.mli` hides representation and documents limitations.
- A fixed example exceeds 64-bit and JavaScript exact-integer limits.
- Generated lists include values scaled beyond machine range; additive identity,
  inversion, subtraction, commutativity, associativity, sum cancellation, and
  conversion round-trip are checked.
- Comparison and empty sum have concrete regression examples.
- Runtime library links only the approved Base and Zarith direct dependencies;
  generation/PPX dependencies occur only in the test library.
- `./tools/check` must pass before calling the slice locally qualified; it runs
  `dune build @all` and forced tests through the isolated switch.

## Build setup status

Dune language 3.0 is a syntax floor, not the final platform support matrix.
The local OCaml 5.3.0 / Dune 3.24.2 environment and transitive dependency lock
are recorded in [ADR 0002](adr/0002-isolated-development-baseline.md).
Build, three expect tests, and 10,000 generated cases pass on macOS x86_64.
The seed is explicitly `loam-quantity-v1`, with 10,000 shrink attempts on failure.
The generated-case counter is checked so the success output cannot represent
zero samples. Test-directory configuration enables inline tests in release/package
mode too. This is finite executable evidence, not an inherited Lean proof or a
qualified release. See `HANDOFF.md` for current state.
