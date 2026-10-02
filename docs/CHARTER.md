# Project charter

Status: initial intent record from the user's design conversation, 2026-10-02.
Working repository name: `loam-ocaml`; final product name is undecided.

## Explicit user requirements

The user wants to:

1. Build LOAM in OCaml for long-term operation, retaining its good design ideas.
2. Make extension and maintenance practical, including third-party maintainers.
3. Support multiple UI forms, including TUI, GUI, and Web UI.
4. Use formal methods as part of design and verification.
5. Account for Lean 4/toolchain evolution as a maintenance concern.
6. Produce professional-quality engineering, also usable as a portfolio shown
   to people associated with Jane Street.
7. Establish repository memory so successor AI assistants do not lose intent.
8. Prepare architecture for a fast, keyboard-oriented, information-dense,
   deterministic future expert UI. The latest phase explicitly excludes TUI/web/
   dashboard/component implementation and anticipatory UI dependencies or OxCaml.
   Do not imitate Jane Street's appearance; the quality goal is typed state,
   functional boundaries, explicit effects, testability, and little accidental
   complexity. See `UI_DIRECTION.md`; earlier layout/interactive-next-step ideas
   are superseded by this preparation-only scope.
9. Continue at the professional OCaml quality target with a functional, immutable
   core and explicit effects, rather than scattered procedural state updates.
   This is an engineering aspiration, not certification; see `ENGINEERING_STYLE.md`
   for the inspected boundary, justified edge/test mutation, and compiler checks.

This is not authorization to publish private data, create cloud infrastructure,
introduce multi-user synchronization, or claim affiliation with Jane Street.

## Accepted initial scope

See [ADR 0001](adr/0001-initial-scope-and-dependencies.md), explicitly approved
by the user after bootstrap:

- Single user, local operation. No initial public access, concurrent multi-user
  product, or synchronization.
- Target macOS/Linux; CLI first, then a practical TUI. GUI/Web only when needed.
- Synthetic-data development; existing LOAM remains authority until a separately
  approved and verified migration. No dual writes.
- Runtime dependencies: Base + Zarith. Test dependencies: ppx_expect +
  Base_quickcheck. Core/Async and storage libraries deferred.
- Every library addition needs a specific capability reason, not convenience.
- Current phase: strengthen UI-independent domain/application/read-model seams
  using existing capabilities. No new UI/framework/cache/time abstraction merely
  in anticipation; UI implementation requires a later explicit scope decision.

## Working interpretation / recommendations

The following are the bootstrap design direction, not separately approved
implementation choices:

- OCaml is the sole intended production semantic engine after a qualified
  transition; Lean is not required to build, test, or release the product.
- Preserve meanings, not the Lean module layout or every historic feature.
- Start with a modular monolith and one useful UI; generalize interfaces only
  when a concrete second consumer needs them.
- Keep primary technical documentation in English for external review.
- Prefer a narrow complete product over many speculative capabilities.
- Keep formal verification small, reproducible, and connected to implementation.

Revisit these explicitly if the user selects another approach; do not silently
reintroduce a permanent Lean/OCaml dual engine.

## Meaning of professional quality

Professional quality means inspectable and maintainable contracts, not a claim
of certification, financial suitability, or comprehensive formal verification.

Before production use, establish:

- Supported platforms and a reproducible build/dependency policy.
- Defined write, retry, concurrency, durability, and recovery guarantees.
- Versioned storage and explicit migration qualification.
- Backup and successful restore exercises, not only backup creation.
- Tests that do not require the original owner's private data or environment.
- An intelligible contributor path, release procedure, and diagnostics.
- Explicit protocol compatibility for independently deployed UI clients, if any.

Latency, scale, supported OS versions, release cadence, and recovery objectives
are not yet specified. Measure and agree targets rather than inventing them.

## Portfolio intent

Demonstrate:

- Idiomatic OCaml abstraction and precise invariant ownership.
- Distinction between type safety, runtime validation, and external assumptions.
- Evidence-based representation and performance decisions.
- Honest model-to-implementation assurance boundaries.
- Real operational usefulness and reviewable source.

The user approved Base, Base_quickcheck, and ppx_expect for specific capabilities.
Their origin is not a substitute for design quality or a reason to add more. No claim is made about hiring
criteria. AI assistance must be described honestly; human decisions and claims
must remain explainable and independently reviewable.

## Explicitly unresolved scope

- Wider compiler/OS support matrix, interactive TUI workflow/layout and toolkit.
  The tested local toolchain baseline is in ADR 0002, not a complete support matrix.
- Any future remote access, multi-user, or synchronization scope requires a new
  decision; these are not current implementation requirements.
- Final storage format and transition from the existing authority.
- License, public hosting, final name, and imported code provenance.

## Completion criterion for this bootstrap

A successor can identify intent, semantic constraints, proposal status, source
references, and the next bounded task without access to the conversation.
The initial dependency budget is now accepted. Product behavior and toolchain
support are qualified incrementally; bootstrap documentation is not that evidence.
