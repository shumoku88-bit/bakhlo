# LOAM OCaml

An independent OCaml household engine: exact quantities, explicit evidence,
retained correction provenance, and honest uncertainty. The goal is a maintainable
product for long-term local use, not a line-by-line Lean translation.

**Development-only. Existing LOAM remains household authority.** No persistence,
writes, migration, UI, public release or complete household admission is qualified.
macOS/Linux are targets; the engine's ordinary suite is qualified only on macOS x86_64.
A one-shot MirageOS macosx hosted engine probe passed. An isolated Ubuntu VM now runs a
minimal C/Solo5-SPT hello; Linux/Mirage engine static linking/boot remains unqualified.
See [host feasibility evidence](docs/VERIFICATION.md#mirageos-hosted-feasibility-one-shot-not-production-support).

## Product direction

The selected goal is a practical standalone MirageOS household application preserving
LOAM meanings, not a novelty demo or Lean implementation clone. The immutable engine
stays reusable; native CLI remains the development/read entrance. Irmin is the leading
persistence candidate, not an adopted dependency or selected backend/schema. First
qualify freestanding build/boot and exact semantics, then storage/admission/publication
and recovery/backup, then a usable client. Read/semantic compatibility work can continue
in parallel without reproducing upstream file layout. See [architecture](docs/ARCHITECTURE.md#selected-product-direction).

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
The example's explicitly supported Exchange gives `exchange-wallet jpy` = `-101`
and `exchange-wallet usd` = `2`, without merging Measures or implying a rate.
Its explicit Reversal `g`/`h` gives `reversal-wallet jpy` = `0` through independent
origin support; both Events remain, without inferred chronology or support.

Only the explicit synthetic grammar is accepted; it is not an upstream adapter or
chosen canonical storage format. Unsupported facts never disappear into a successful
empty image. See [grammar](cli/current_fixture_input.mli) and
[source/query interfaces](application/current_quantity_query.mli).

## Retained scope

- Local single user; CLI is the development/read entrance. First usable TUI/GUI
  remains undecided; no current UI/network/synchronization.
- Immutable functional engine; process/file I/O only at explicit edges.
- Runtime Base + Zarith; tests ppx_expect + Base_quickcheck. No speculative framework.
- General Events remain broader than ordinary Movements. Current source admission
  covers ordinary + explicitly qualified Exchange/Reversal Actual: optional Event-local
  keys remain unique within each Event, ALL retained Effects nonzero, and ordinary
  Events/targets conserve each Measure. Exchange selects two exact keys with distinct Measures,
  negative source/positive destination Effects AND Measure totals, no third Measure;
  additional Effects in those Measures survive, without inferred fee/rate semantics.
  Exchange subjects cannot participate in Event correction. Reversal independently names
  two retained Events with globally disjoint endpoints and exact physical multiset inversion;
  keys/order do not matter, multiplicity does. Independent target admission derives
  ordinary reversal balance or permits a qualified Exchange's inverse as an exception;
  pair cancellation alone does not.
  Neither Event is auto-deleted or excluded from quantity/presence calculations. Independent retained
  date history and ordinary Event corrections remain qualified.
  Date corrections are closed disjoint same-Event paths with one current occurrence
  fact per retained Event; all superseded dates survive and must remain valid.
  Optional Event descriptions retain exact human recognizer text against retained IDs;
  they are not Merchant/Purpose classifications, support or inherited correction metadata.
  Independent Event Merchant dispositions distinguish unresolved absence, explicit
  nonmerchant and an exact role-free external party ID; no registry/payment-role inference
  or automatic correction inheritance.
  Optional original presented/charged amounts retain one positive Quantity and explicit
  Measure per stable correction root; current terminal association is derived without
  rewriting the fact, adding Effects, exchange rates or quantity/presence support.
  Directional relation units have independent IDs, explicit Household/External debtor
  and creditor, a retained Event/key source and positive quantities. Individual and
  total same-source coverage cannot exceed the Effect's absolute quantity, regardless
  of direction/party. Measure comes from the Effect; signs do not infer relation roles.
  Superseded sources remain exact, without correction/Reversal transfer or balance
  support. Exact discharge facts separately name Event/Relation/positive quantity;
  duplicate correspondences, source-Event self-discharge and individual/aggregate
  over-discharge refuse. Missing references refuse globally, not inert crash residue.
  Remainders are derived from original quantity minus supplied discharge total in one
  qualified snapshot, not retained balances or proof of complete real-world fulfillment.
  Measure stays inherited from the relation's source; no physical Effect/sign/date
  inference, automatic correction/Reversal transfer or quantity/presence support.
- Exact assertion groups retain independent reflected-root cuts. Origin is explicit,
  not inferred from activity. Opening explicitly names a current Event containing the
  coordinate; it is not a second scalar or implicit origin. Presence retains one shared
  root cut, not a scalar; ANY unreflected matching Effect invalidates it, even net zero.
  Exact/present payloads are disjoint; all four families must be globally separated.
- Other structured metadata, relation completeness/lifecycle, target-local crash activation,
  settlement, historical
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
