# LOAM OCaml

An independent OCaml household engine: exact quantities, explicit evidence,
retained correction provenance, and honest uncertainty. The goal is a maintainable
product for long-term local use, not a line-by-line Lean translation.

**Development-only. Existing LOAM remains household authority.** No persistence,
writes, migration, UI, public release or complete household admission is qualified.
macOS/Linux are targets; only macOS x86_64 has been exercised.

## Build and try

```sh
./tools/bootstrap
./tools/check
./tools/opam exec -- dune exec loam-ocaml -- --help
./tools/opam exec -- dune exec loam-ocaml -- check-movement \
  --effect wallet jpy -1000 --effect food jpy 1000
./tools/opam exec -- dune exec loam-ocaml -- inspect-current-fixture \
  examples/current-preview.fixture wallet jpy
```

Movement checking is structural validation, **not recorded**. Fixture querying is
read-only and conditional on supplied evidence: `wallet jpy` gives assertion
`1000` + unreflected delta `-10` = `990`; `food jpy` gives origin quantity `160`;
`offset usd` gives opening quantity `-7` through explicit current Event `b`;
`quiet jpy` gives supported zero. `pantry jpy` is known nonzero but its exact amount
is unknown (exit 4/stdout). `stale jpy` has net-zero unreflected activity and is no
longer supported; `unsupported jpy` lacks evidence (both exit 3/stdout).
Load/admission failures exit 1; syntax failures exit 2 (stderr, no stdout).

Only the explicit synthetic grammar is accepted; it is not an upstream adapter or
chosen canonical storage format. Unsupported facts never disappear into a successful
empty image. See [grammar](cli/current_fixture_input.mli) and
[source/query interfaces](application/current_quantity_query.mli).

## Retained scope

- Local single user; CLI first, eventual TUI. No current UI/network/synchronization.
- Immutable functional engine; process/file I/O only at explicit edges.
- Runtime Base + Zarith; tests ppx_expect + Base_quickcheck. No speculative framework.
- General Events remain broader than ordinary Movements. Current source admission
  covers ordinary Actual, including optional Event-local Effect keys:
  unique retained keys within each Event, all retained Effects nonzero,
  per-Measure conservation, independent retained date history and Event corrections.
  Date corrections are closed disjoint same-Event paths with one current occurrence
  fact per retained Event; all superseded dates survive and must remain valid.
  Optional Event descriptions retain exact human recognizer text against retained IDs;
  they are not Merchant/Purpose classifications, support or inherited correction metadata.
- Exact assertion groups retain independent reflected-root cuts. Origin is explicit,
  not inferred from activity. Opening explicitly names a current Event containing the
  coordinate; it is not a second scalar or implicit origin. Presence retains one shared
  root cut, not a scalar; ANY unreflected matching Effect invalidates it, even net zero.
  Exact/present payloads are disjoint; all four families must be globally separated.
- Structured metadata, Exchange/Reversal, historical
  completeness and full normalized Actual admission are still unsupported.

No public API/storage compatibility promise exists during this unreleased phase.
Remove obsolete routes rather than maintain prototype compatibility. Licensing,
source reuse, public publication, storage and operational cutover require decisions.
Lean is optional development evidence, never a production build/test/release dependency.

## Documentation

- [Semantic contract](docs/SEMANTIC_CONTRACT.md): meanings that must survive.
- [Architecture](docs/ARCHITECTURE.md) and public `.mli`: implemented boundaries.
- [Verification](docs/VERIFICATION.md): instruments, evidence and limits.
- [Development](docs/DEVELOPMENT.md): isolated toolchain and commands.
- [References](docs/REFERENCES.md): narrow upstream owners and correspondence gaps.
- [Contributing](CONTRIBUTING.md), [pit instructions](AGENTS.md),
  [handoff](docs/HANDOFF.md): workflow and next bounded work.

Prior research is a design asset, not an OCaml correctness certificate. Missing
operations do not invalidate Core expressiveness. Professional quality means
inspectable contracts and failure behavior, not feature/theorem counts or certification.
