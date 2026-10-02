# Future UI readiness — engineering boundaries, not interface implementation

Status: current user-authorized phase, replacing the earlier proposed next step
of interactive traces/screens. **Do not implement a UI in this phase.**

## Quality goal

Prepare for a fast, keyboard-oriented, information-dense, deterministic expert
engineering tool: explicit meaningful state, invalid-state resistance, repeatable
tests, functional boundaries, explicit effects, and little accidental complexity.
Do not imitate Jane Street's appearance or claim an official UI standard.

A future framework must be replaceable. No terminal UI, web UI, dashboard, visual
component system, screen sketch implementation, or framework evaluation is the
next task merely because the engine has a CLI.

## Dependency policy

Keep runtime Base + Zarith and test ppx_expect + Base_quickcheck. No Bonsai,
Bonsai_term, Notty, Lwd, React, web framework, Core/Async, or other library for
anticipation/branding. Do not introduce OxCaml to enable a future toolkit.
Every later dependency still needs a concrete capability reason and approval.

Domain and application compile independently of presentation/CLI and without
any UI package installed. Internal library boundaries are not third-party
package additions or an external compatibility promise.

## Existing capability and implemented seam

OCaml checks ordinary Movement structure and has a conditional zero-origin
quantity projection over an explicitly supplied Movement basis. It has no stored/
admitted Actual history, operational balance report, schedule/cycle query, loader,
or date operation. Do not manufacture those read models or UI states from Lean.

```text
source dependencies:

CLI -> text presentation -> application -> domain
CLI ---------------------> application -> domain

future frontend/test -> application (no argv or text projection required)
```

`Movement_check.run` accepts a typed command and returns an abstract structured
preview or domain refusals. The command carries only actual input Effects. This
operation is stateless: no dummy session/state machine is added.

The preview exposes Measure, original Effects, and exact positive total. The
existing aggregate is materialized once per successful command, not recalculated
by formatting. This is an in-memory answer, not canonical state or a cache with
an invented invalidation protocol. It remains **structurally valid, not recorded**.

`Zero_origin_projection` builds an immutable coordinate index once and answers
pure lookups with independent origin support. It never infers origin from activity
or claims current Actual/temporal completeness. It has no text renderer or CLI/UI
adapter; see [bounded contract](BALANCE_SLICE.md).

`Movement_text` is a pure projection for the existing CLI. Other clients can
choose their own representation from typed values. They do not parse CLI text,
manufacture argv, or repeat accounting validation/aggregation.

## Rules as capabilities grow

### Meaning and state

- Introduce typed commands/transitions only for real operations with explicit
  inputs and result. A stateful operation should make its state transition visible,
  not scatter mutations through unrelated helpers. Do not build a universal bus.
- Introduce load/edit/review variants only when those states actually exist.
  Prefer meaningful sums to contradictory independent booleans, not type theatre.
- Preserve Actual/Scheduled, amount/presence, anchor/history, measured amount/
  converted value, and accepted/review-required distinctions when relevant.
- A current answer needs its qualified evidence; unknown is not zero. Rendering
  never promotes a projection to household authority or a preview to permission.

### Computation and projections

- Produce structured semantic answers before formatting. No preformatted report
  strings as the primary application contract, UI-specific JSON, or layout fields.
- Add read models for actual queries, not generic view-model families. There is
  currently no basis for available-today, next-payment, cycle, or trend answers.
- Column choice, sorting, grouping, truncation, scrolling, selection, highlighting,
  and date formatting belong to the client/projection, not accounting computation.
- Focused row, tab, cursor, hover, offsets, dimensions, colors, widgets, and key
  events stay outside Domain and Application. A meaningful period/range is an
  explicit query input; previous-cycle/month-containing-date navigation may belong
  in Application when those operations exist, not as screen movement.

### Effects and time

- Business functions take ordinary values. Filesystem, processes, environment,
  clocks, and terminal access are explicit edge responsibilities.
- When time-dependent semantics are added, supply the date/time coordinate
  explicitly. Do not read an implicit global now. No Clock interface is needed
  for the current timeless validation/conditional projection operations.
- No hidden randomness. If a real capability ever needs randomness, inject its
  source. Property-test seeds are explicit and independent of business functions.

### Histories and cost

- Do not reread/decode canonical data or recompute reports on every future
  navigation/redraw action. Keep admitted input construction, semantic queries,
  structured answers, and rendering separate as those capabilities arrive.
- Expose expensive computations as explicit operations over qualified inputs so
  measured caching/incremental work can later preserve the same semantics.
- Do not add a cache, revision scheme, incremental framework, or indexed history
  without actual evidence. No history or latency benchmark exists here yet.
- The conditional projection's actual query needs a coordinate index; construction
  groups supplied Effects once and lookups do not scan that basis. This is an
  immutable answer model, not an indexed canonical history or mutable cache.
- Current Movement checks traverse only submitted Effects; exact arithmetic cost
  also depends on integer size. CLI text projection formats all requested Effects.
  This is not a large-history UI latency guarantee.

## Testable seams now

Construct small typed fixtures, submit an application command, and inspect typed
success/refusal values without a terminal, files, current time, or CLI parser.
Test identical-input replay, exact aggregates, represented order/multiplicity,
refusal ordering, and immutable answers under independent client projections.

Compile a valid application-only client and assert that an invalid preview cannot
be forged. Preserve existing CLI golden output/exit/stream behavior as one client.
Pure tests do not establish terminal ergonomics, rendering latency, accessibility,
full formal correctness, or future publication behavior.

See [ADR 0003](adr/0003-ui-independent-application-boundary.md),
[architecture](ARCHITECTURE.md), and [handoff](HANDOFF.md) for current implementation,
qualification, and the next bounded engine task. UI implementation needs a new
explicit scope decision; it is not the automatic follow-on to this preparation.
