# Contributing

This repository has a pure-domain engine and validation-only CLI, not a released
or operational household system. Current work prepares UI-independent application
operations and semantic read models; it does not implement a UI or add anticipated
frameworks. See [ADR 0003](docs/adr/0003-ui-independent-application-boundary.md).
Read `AGENTS.md` and the charter before proposing implementation changes.

## A useful contribution

1. Names a concrete problem and an observable acceptance criterion.
2. Explains the responsible module/contract and nearest semantic neighbors.
3. Adds focused tests or other evidence without overstating their scope.
4. Keeps dependencies and abstractions proportional to the actual requirement.
5. Updates the relevant decision/handoff record when the next action changes.

Use synthetic data only. Do not submit personal financial information, real
household exports, local credentials, or identifiable diagnostics.

## Toolchain

The direct dependency budget is accepted in
[ADR 0001](docs/adr/0001-initial-scope-and-dependencies.md). The isolated baseline
and exact versions are recorded in [ADR 0002](docs/adr/0002-isolated-development-baseline.md).
Read [development setup](docs/DEVELOPMENT.md) for prerequisites and guarantee limits.

```sh
./tools/bootstrap
./tools/check
```

Build and tests pass on macOS x86_64 using local OCaml 5.3.0 and the tracked lock.
The checks include expect/generated tests, real CLI cram tests, and compiler
boundary tests. The baseline is not a completed Linux/macOS version matrix. Do not install a
global environment or commit local compiler, package cache, or build artifacts.

Every added direct library needs a concrete capability reason and named consumer.
Record alternatives, runtime/test scope, transitive cost, and revisit conditions.

## Review expectations

Keep changes small enough to inspect. Use explicit public interfaces and explain
non-obvious invariants. Benchmarks must include workload and environment; formal
results must include assumptions and implementation correspondence.

Record AI assistance honestly when relevant. Do not attribute unperformed review,
experiments, design decisions, or authorship to a human or tool.

## Source reuse and public release

Licensing is unresolved. Before copying code, resolve its upstream license and
attribution requirements as well as this project's license. Remote publication,
release policy, and contributor licensing arrangements remain open decisions.
