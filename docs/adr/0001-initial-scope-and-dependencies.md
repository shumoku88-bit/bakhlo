# ADR 0001 — Initial scope and capability-based dependencies

Status: ACCEPTED by the user's explicit approval on 2026-10-02.

## Scope

- Single user, local operation initially.
- macOS and Linux are target platforms; specific compiler/OS support versions
  still need qualification.
- Start with a CLI to exercise the engine; first practical UI is TUI.
- GUI/Web are deferred until needed. Preserve presentation-neutral boundaries,
  but do not implement a speculative second UI now.
- Public network access, multiple concurrent users, and synchronization are out
  of initial scope. Single-user use does not eliminate process races or retries.
- Develop against synthetic data only. Existing LOAM remains the operational
  authority. Migration requires separate validation and approval; no dual writes.

## Direct dependency budget

| Dependency | Scope | Capability that justifies it |
| --- | --- | --- |
| Base | Runtime | Basic collections and explicit comparison APIs |
| Zarith | Runtime | Exact signed integer quantities without machine overflow |
| Base_quickcheck (`base_quickcheck`) | Test only | Generated invariant checks with shrinking |
| ppx_expect | Test only | Readable output regression checks, later CLI/TUI/serialization |

Core and Async are not introduced. No storage dependency is introduced until the
storage decision. Do not install the umbrella `ppx_jane` in place of the selected
PPX merely for convenience.

Every added direct library must have a concrete capability reason and a named
consumer. "Convenient", "popular", or "used by Jane Street" is insufficient.
Before adding one, record the gap, alternatives, runtime/test scope, transitive
cost, and removal/revisit condition. Toolchain and transitive dependencies still
need inspection; this table does not imply that only four packages are installed.

## Alternatives and consequences

A larger Core/Async stack was discussed but deferred until a specific need.
A universal UI or storage framework would add obligations without an initial
consumer. Stable runtime/library version selection remains separate from approval
of the dependency families; no support policy is inferred from the host compiler.

This budget permits a small pure-domain implementation without deciding storage,
TUI toolkit, or wire format. It does not authorize a global package installation.

## Revisit triggers

A concrete workflow, platform, concurrency requirement, or missing capability may
justify another library. Review and record that reason before introduction.
Reassess dependencies whose original consumer or capability has disappeared.
