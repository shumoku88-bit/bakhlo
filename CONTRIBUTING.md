# Contributing

Bakhlo is unreleased; its maintainer records the household with it daily since
2026-10-21. Read README and the current
[handoff](docs/HANDOFF.md); consult relevant semantic/interface contracts for the task.
Ordinary tests use synthetic data; separately approved private candidate work stays ignored.
[AGENTS.md](AGENTS.md) also applies to pits. Book or config format changes need an approved migration (AGENTS.md).

## A useful change

- Names a concrete consumer, observable acceptance criterion and invariant owner.
- Uses existing tests and independent expectations; adds tools only for a concrete gap.
- Does not require a new task document or qualification campaign per change.
- Removes obsolete code/docs when appropriate; never weakens semantics just to cut lines.
- Keeps interfaces, verification and handoff current without copying inventories.
- Is small enough to review and qualify independently.

No personal financial information, real exports, credentials or identifiable logs.
Material dependencies, UI, storage, source reuse, licensing, publication and operational
cutover require their own decisions. See [accepted dependency budget](docs/adr/0001-initial-scope-and-dependencies.md).

## Functional core and explicit edges

Domain/Application/S-expression code computes immutable values; `store/` owns file I/O
and `tui/shell` the remaining effects. No hidden clock, filesystem, randomness, global
business state or reverse UI dependency in the engine.
`Result.bind` sequences values, not effects; `Printf.sprintf` is formatting, not output.

Do not ban every loop/ref or disguise I/O as an ornamental monad. Local mutation needs
an owner and concrete reason; test-only counters assert actual case execution.
Temporary indexes are mechanical aids, not authorities, durable facts or evidence priority.

Root Dune retains standard flags plus `-strict-sequence` and fatal warnings 8/9/11
in all profiles. Explicitly handle closed semantic constructors and record fields.
These guards detect selected mistakes, not general purity/correctness; deliberate
ignore/unsafe casts/catch-alls remain review concerns. `compiler_policy.t` tests complete
controls and counterexamples in dev/release, including relevant diagnostics.

## Qualification

```sh
./tools/bootstrap
./tools/check
```

Use repository wrappers, never global opam/dune configuration. See
[development](docs/DEVELOPMENT.md) for prerequisites, package and engine-only checks.
The host qualification is macOS x86_64, not the entire target matrix.

Benchmarks name workload/environment and excluded costs. Formal results name statement,
assumptions, trust boundary and OCaml correspondence gap. Missing tools or unrun checks
are limitations, not successes.

Review exact changes and stage only intended checked files. Do not include another
person's unchecked work. Pushing follows AGENTS.md; no release without authority.
Disclose AI assistance honestly; do not invent authorship,
review, experiment results, affiliation or superiority. Licensing is unresolved: resolve
ownership/attribution and package metadata before source copying or public release.
