# ADR 0003 — Prepare application/read-model boundaries, not a UI

Status: implementation direction authorized by the user's explicit phase request.
Qualification results belong in `HANDOFF.md`; this document is not proof of them.

## Scope and stop point

Prepare the current OCaml functionality for future fast, keyboard-oriented,
information-dense, deterministic expert tooling. Do not build a TUI, web UI,
dashboard, visual component system, screen layout, or speculative UI state machine.
Do not imitate Jane Street's appearance or add libraries for their branding.

Keep Base + Zarith runtime and ppx_expect + Base_quickcheck test dependencies.
No UI packages, OxCaml, incremental framework, cache, clock abstraction, or
universal command framework is introduced. A later UI framework is replaceable.

## Existing capability and obligations

- D: the only implemented application-facing action is checking an ordinary
  Movement. There is no persisted history, report query, date/cycle/schedule
  operation, or interactive navigation in the OCaml implementation yet.
- P: domain validation has abstract types, structured refusals, exact arithmetic,
  and executable checks. The CLI already has tested output and exit semantics.
- R: make that action available without CLI arguments/formatting; expose its
  existing semantic preview as structured values; prevent formatting from running
  business validation or recalculating the preview's aggregate.

## Decision

```text
source dependencies (outer clients depend inward):

CLI -> text presentation -> application -> domain
CLI ---------------------> application -> domain

future clients can call application directly without presentation or CLI
```

- `Movement_check` is a narrow pure application operation with a typed command
  containing Effects. Its result is an abstract preview or structured domain
  refusals. The operation is stateless: no dummy State/unit/session is added.
- The preview retains the validated Movement and the existing derived positive
  total. Accessors expose Measure, represented Effects, and exact positive total.
  It has no strings, layout, selection, terminal state, or UI-specific JSON.
- Compute that aggregate when answering the command, not when formatting a view.
  This is materializing the existing query answer, not a new cache, independently
  authoritative fact, or performance claim. No invalidation protocol is invented.
- `Movement_text` formats the structured answer/refusals. It cannot accept raw
  commands or rerun validation; it has no filesystem, clock, or process effects.
- CLI owns argument grammar, help, syntax errors, streams, and exit codes. It
  submits the same application command that a future frontend or test can submit.
  Preserve the existing CLI golden output and exit behavior.

Separate internal Dune libraries make the dependency direction executable. They
are within the same package; no external dependency or stable public API contract
is added. Domain/application build targets do not require text/CLI or UI packages.

## Alternatives

- Keep business answer construction in the CLI: rejected because future clients
  would have to reuse argv or repeat semantics, and formatting would own aggregate
  computation.
- Add a generic service/view-model/event framework: rejected as speculative.
- Add session state/load flags/clock injection now: rejected because this action
  has no loaded model, asynchronous operation, or time-dependent meaning.
- Add all balance/schedule/cycle models from the Lean system: rejected because
  they are not existing OCaml capabilities and need separately qualified semantics.

## Acceptance evidence

- Pure application fixtures use typed Effects, not argv or a terminal.
- Repeated identical commands produce observably identical success/refusal values.
- Input representation, exact aggregate, and domain refusals are preserved.
- Abstract preview cannot be forged by a well-typed external client.
- CLI output/exit goldens remain unchanged; repeated formatting does not change
  the structured answer.
- Build domain/application separately and run normal/package-mode tests.
- Dependency manifests/lock and installed dependency inventory remain unchanged.

## Future rules, not implementations

Introduce state transitions only for actual stateful operations. Keep Actual,
Scheduled, evidence completeness, valuation, and review-required distinctions
when those capabilities arrive. Time-dependent queries must accept explicit
coordinates; never call global now from business logic. Load/render/navigation
state stays outside accounting semantics. Semantic period navigation may belong
in application only when date/cycle queries exist.

Histories and expensive reports are absent now. When added, separate admitted
input/model construction from pure query results and presentation. Measure real
cost before caching/incremental work, naming its consistency scope and preserving
semantics. This phase does not establish large-history latency guarantees.
