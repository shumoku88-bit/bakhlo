# LOAM OCaml — working name

**Status: Movement validation, conditional zero-origin quantity projection, and validation-only CLI. No UI or household writes.**

An independent OCaml implementation of LOAM, intended for long-lived household
use, third-party maintenance, and presentation as an engineering portfolio to
people associated with Jane Street. This is not affiliated with or endorsed by
Jane Street.

The goal is not a line-by-line translation of the Lean implementation. Preserve
LOAM's useful semantic boundaries while designing a small, idiomatic, maintainable
OCaml product.

## Product intent

- Exact quantities, explicit evidence, retained correction provenance.
- Unknown or incomplete answers never silently become zero.
- Shared semantics usable from TUI, GUI, Web UI, and CLI.
- Operational data continuity and inspectable failure/recovery behavior.
- Development and maintenance accessible without Lean expertise.
- Formal methods chosen for concrete questions, with honest assurance limits.

OCaml is the intended production implementation platform. Existing Lean results
are reference evidence, not proofs of the future OCaml implementation. Whether
any individual formal artifact needs ongoing maintenance remains a scoped design
decision; production build/test/release must not require Lean.

## Start here

1. [Project charter](docs/CHARTER.md): user requirements versus recommendations.
2. [Semantic contract](docs/SEMANTIC_CONTRACT.md): meaning to preserve.
3. [Architecture proposal](docs/ARCHITECTURE.md): boundaries, not a frozen design.
4. [Decision register](docs/DECISIONS.md): open choices and acceptance evidence.
5. [Verification strategy](docs/VERIFICATION.md): what each kind of evidence proves.
6. [Handoff](docs/HANDOFF.md): current state and the next bounded task.

Contributors and AI assistants must read [AGENTS.md](AGENTS.md). See also
[CONTRIBUTING.md](CONTRIBUTING.md) and the [source reference index](docs/REFERENCES.md).

## Development status

Initial scope is accepted: local single user, macOS/Linux, CLI first and TUI as
eventual practical UI. Current engine work remains independent of UI: no
TUI, web UI, dashboard, components, or anticipatory toolkit dependencies. See
[ADR 0001](docs/adr/0001-initial-scope-and-dependencies.md) and
[ADR 0003](docs/adr/0003-ui-independent-application-boundary.md).

Direct runtime dependencies are Base + Zarith; test dependencies are ppx_expect +
Base_quickcheck. Every library addition needs a concrete capability reason.
Core, Async, and storage libraries are not introduced.

The engine exposes abstract Quantity, distinct Measure/Locus identifiers, neutral
Effects, and validated ordinary Movements. `application/movement_check.mli`
exposes the existing operation and abstract structured preview without argv,
formatting, I/O, or implicit time. `presentation/movement_text.mli` projects that
answer to existing CLI text without revalidation or aggregate recomputation.
Domain/application compile independently of presentation/CLI. See the
[Quantity contract](docs/QUANTITY_SLICE.md),
[Movement/CLI contract](docs/MOVEMENT_SLICE.md), and
[UI direction](docs/UI_DIRECTION.md). The final TUI is not implemented.

`application/zero_origin_projection.mli` adds an immutable coordinate index for
one conditional quantity question. Explicit zero-origin support is independent
of activity; unsupported coordinates return `Origin_unknown`, not zero. These
quantities depend on the supplied Movement basis, not admitted current/historical
Actual, correction selection, or purchasing power. See [contract](docs/BALANCE_SLICE.md).

From the repository root:

```sh
./tools/bootstrap
./tools/check
```

Setup keeps opam, its root, and an OCaml 5.3.0 switch inside the repository without
changing the global OCaml installation or shell configuration. The registry and
transitive dependencies are pinned. See [development setup](docs/DEVELOPMENT.md)
for prerequisites, versions, update policy, and limitations.

The core uses immutable data and pure functions; process I/O is isolated at
`bin/main.ml`. Strict sequencing and selected fatal compiler warnings remain
active in release builds too. See [functional-core review](docs/ENGINEERING_STYLE.md)
for the actual boundary, test-only counters, and limits of these checks.

On macOS x86_64, build, 23 expect tests, and three cram suites pass. Quantity,
Movement, application replay, and conditional projection each execute 10,000
deterministic generated cases. A clean domain/application-only build does not build presentation/CLI.
Cram suites exercise the real CLI, application-only clients, abstract type
boundaries, and compiler-policy controls/counterexamples in dev/release. Linux and Apple
Silicon are targets, not yet qualified platforms. This is finite executable
evidence, not a formal correctness proof or full operational admission. There
is no admitted Actual history/report engine, storage, migration, or public release, and no
large-history latency guarantee yet. No cache, incremental framework, clock
abstraction, or UI state is invented for this preparation. Local package metadata
is not a publication or stable-API promise.

## Try a synthetic movement

```sh
./tools/opam exec -- dune exec loam-ocaml -- check-movement \
  --effect wallet jpy -1000 \
  --effect food jpy 600 \
  --effect transport jpy 400
```

The preview says **structurally valid (not recorded)**. Amounts are exact quanta,
not inferred display currency units. Empty/zero Effects, mixed Measures, and
imbalance are refused. No household files are read or written, no identities are
allocated, and no current household policy/date checks are implied. Help:

```sh
./tools/opam exec -- dune exec loam-ocaml -- --help
```

Future examples, fixtures, benchmarks, and demos must use synthetic data.
Existing household data must not enter this repository.

## Portfolio standard

Prefer a small working system with explainable contracts over a broad unfinished
framework. Show representative source, executable counterexamples, measured
trade-offs, and the limits of formal claims. Primary technical entry documents
are in English; user-facing discussion may be in Japanese.

The intended review path is: a five-minute overview, a thirty-minute source and
test walkthrough, then optional deep dives into proofs, failure injection, and
performance. This is a presentation goal, not a claim about any organization's
hiring criteria.

## Licensing and publication

No license has been selected and no remote publication is authorized by this
bootstrap. Decide licensing and source-reuse provenance before importing code or
publishing. Do not assume this repository grants open-source reuse rights yet.
