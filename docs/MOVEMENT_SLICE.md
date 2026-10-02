# Movement validation and CLI slice

Status: implementation contract for the user's instruction to proceed, 2026-10-02.
No storage, operational migration, new library, or TUI toolkit is selected here.

## Observable

Validate an ordinary single-Measure signed movement from explicit Effects. The
CLI presents either a validation-only preview or a structured refusal. Neither
case reads household state, allocates durable identity, or records anything.

## Obligations and prior evidence

- D: semantic contract S3/S4 requires exact arithmetic, explicit Measure, and
  ordinary Movement conservation. The approved stack can implement this purely.
- P: `Quantity` already has executable checks; these are finite tests, not proofs.
- P: upstream `Loam/Application/PracticalMovement.lean` qualifies nonempty,
  nonzero, single-Measure, zero-sum Effects. Its general Event and world admission
  impose separate rules. Those proofs do not transfer to OCaml.
- R: protect identifier meanings and validated construction, preserve represented
  Effects, expose usable deterministic refusal, and check the CLI process boundary.

No upstream source is copied. Implement the stated behavior independently.

## Types and validation

- `Identifier.Measure.t` and `Identifier.Locus.t` are distinct abstract types.
  Nonempty opaque strings preserve exact identity, including case and whitespace;
  no catalog membership, aliasing, or locale policy is inferred. Text representation
  rules belong to adapters, not a hypothetical storage format. Rendering escapes
  arbitrary input so opaque identity cannot inject terminal control sequences.
- `Effect.t` binds a Locus, Measure, and exact Quantity. Zero is representable in
  a neutral Effect; only the ordinary Movement entrance rejects it.
- `Movement.t` is abstract and constructible only by its validator.
- Empty input is refused. Every represented quantity must be nonzero, every Measure
  must equal the first Effect's candidate, and the exact signed sum must be zero.
- Shape refusals are deterministic, in input order, with one-based Effect positions.
  Collect zero/mixed-Measure errors; do not sum quantities across different Measures
  to produce a fake numeric balance error. Check residual only after shape passes.
- Preserve order, multiplicity, and same-Locus changes. Do not silently merge,
  cancel, sort, deduplicate, or demand different source/destination Loci.
- Positive total is derived from validated Effects, not independently retained
  household evidence or a user-supplied total that can disagree.

This is structural/practical movement validation, **not full publication admission**.
Dates, policy-approved Loci, correction currentness, Event identities, relation
references, world updates, and persistence are explicitly out of scope. The name
and UI must not imply those checks have happened.

## CLI contract

```text
loam-ocaml check-movement --effect LOCUS MEASURE QUANTA [--effect ...]
```

Each Effect carries its Measure explicitly, so mixed-Measure mistakes can be
reported instead of coerced. Quantity input is `[+-]?[0-9]+` only: no floats,
underscores, radix prefixes, surrounding whitespace, rounding, or unit conversion.
Leading zeros and a plus sign are presentation spellings of the same integer.
Output is exact quanta, not display currency units.

The adapter parses arguments and submits typed `Movement_check.command` values
to the application. It returns a typed `Help`, `Validated` structured application
preview, or `Refused` outcome. The abstract preview exposes Measure, Effects,
and exact positive total; the aggregate is materialized when answering, not when
formatting. `Movement_text` owns pure text projection. See ADR 0003 for the
preparation-only boundary refactor; the existing CLI output/exit contract is
unchanged. The executable only
reads argv, writes chosen streams, and exits:

- 0: help or successful validation-only preview, stdout only.
- 1: Movement refusal, stderr only.
- 2: command/argument/quantity/identifier syntax refusal, stderr only.

No args does not pretend that a TUI exists. Unknown arguments fail; there is no
implicit data root, default Measure, default quantity, balancing suggestion,
transaction kind, or storage operation. These commands are local development
interfaces, not an external compatibility promise.

## Acceptance checks

1. Explicit interfaces protect Measure/Locus separation and validated construction.
2. Concrete tests cover empty, zero, mixed, residual, split, duplicate, same-Locus,
   and beyond-machine-range cases.
3. Generated tests compare exact validation with a transparent Zarith oracle and
   exercise balanced pairs, perturbation, negation, and input preservation. Pin
   seed/count and confirm the generated cases actually execute.
4. Expect tests cover help, syntax refusal, exact preview, semantic refusal, stream
   choice, and control-character escaping.
5. Built-in Dune cram checks invoke the real executable and assert exit behavior.
6. Product checks and package-mode tests run through the isolated environment.
7. No runtime/test dependency is added; no data or upstream source is changed.

The current phase in `UI_DIRECTION.md` explicitly postpones TUI/web/dashboard/
component implementation and speculative UI states/dependencies. Prepare semantic
boundaries, not a layout or a claimed Jane Street UI standard.
