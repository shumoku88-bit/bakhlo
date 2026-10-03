# LOAM OCaml — working name

**Status: Movement validation, conditional quantity answers and correction-root cuts. Validation-only CLI; no UI or household writes.**

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

`application/correction_check.mli` resolves a raw correction's target/replacement
from an identity-unique immutable Event memory, retaining both observations.
Missing endpoints are typed refusals. General anonymous-Effect Events are not
ordinary Movements; closure does not establish currentness or apply corrections.
See [endpoint contract](docs/CORRECTION_ENDPOINT_SLICE.md).

`application/correction_frontier.mli` qualifies a whole supplied correction list
as closed, unique-target/unique-replacement, and acyclic. It retains original
observations/edges and derives terminals plus untouched Events; branches, merges,
and cycles are typed refusals, never order-selected winners. This is not admitted
current Actual or write permission; see [contract](docs/CORRECTION_FRONTIER_SLICE.md).
It now materializes abstract root-to-terminal lineages, retaining original facts.
Roots survive fresh-tail correction extension, not arbitrary source-scope edits;
see [lineage contract/model correspondence](docs/ROOT_LINEAGE_SLICE.md).
`application/reflected_root_cut.mli` validates independent reflected-root declarations
against that immutable frontier and excludes whole lineages while retaining source
facts. Duplicate/absent/non-root IDs refuse explicitly; this is not quantity support
or current Actual. See [cut contract](docs/ROOT_CUT_SLICE.md).

`application/current_quantity_projection.mli` now answers one anonymous group's
exact coordinate assertions plus unreflected terminal Effects. It retains the cut
and premises, exposes exact decomposition, and returns `Assertion_unknown` without
an assertion—even with activity or zero delta. This is one supplied group, not full
multi-group support or admitted household balances. See [contract](docs/CURRENT_QUANTITY_SLICE.md).
`application/current_quantity_groups.mli` now composes anonymous groups against ONE
supplied frontier, preserving their independent cuts and refusing shared live
coordinate ownership. Explicit immutable re-observation replaces only selected
assertions/cuts; it is not a list-order winner, history or write. See
[group contract](docs/CURRENT_GROUPS_SLICE.md). Actual/support-family admission is separate.

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

[Verification](docs/VERIFICATION.md) owns the current test inventory, independent
oracles, bounds and macOS x86_64 qualification. Linux/Apple Silicon remain targets,
not qualified platforms. [Optional specification laws](formal/README.md) are neither
OCaml refinement proofs nor product requirements. There
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

The quality ambition is independent of popularity: rigorous retained meanings,
operational reliability, and maintainability, informed by LOAM's accumulated
research/verification. Intentionally omitting unused features does not lower the
assurance target; superiority to other OSS is an aspiration, not a measured claim.

Prefer a small working system with explainable contracts over a broad unfinished
framework. Show representative source, executable counterexamples, measured
trade-offs, and the limits of formal claims. Primary technical entry documents
are in English; user-facing discussion may be in Japanese.

Preserve the Core's researched expressive capacity, not only the currently
implemented feature list. The [correspondence map/proposed next steps](docs/CORE_CORRESPONDENCE.md)
separates prior evidence, retained distinctions, and OCaml qualification gaps;
unimplemented derived capabilities are not automatically missing Core concepts.

The intended review path is: a five-minute overview, a thirty-minute source and
test walkthrough, then optional deep dives into proofs, failure injection, and
performance. This is a presentation goal, not a claim about any organization's
hiring criteria.

## Licensing and publication

The user authorized initial commit and private GitHub hosting at
[shumoku88-bit/loam-ocaml](https://github.com/shumoku88-bit/loam-ocaml); private
visibility was rechecked. This is not a public release or license selection.
No license is selected. Resolve licensing/source-reuse provenance before importing
code or public publication; do not assume open-source reuse rights.
