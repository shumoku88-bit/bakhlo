# Bakhlo

An independent OCaml household engine: exact quantities, explicit evidence,
retained correction provenance, and honest uncertainty. The goal is a maintainable
product for long-term local use, not a line-by-line Lean translation.

**Development-only. Existing LOAM remains household authority.** No production persistence,
household writes, migration, UI, public release or complete household admission is qualified.
The locked engine baseline is qualified on macOS x86_64 and isolated Ubuntu 24.04 x86_64;
the new text-read increment is checked on macOS only, not freshly replayed in Linux/Mirage.
A bounded MirageOS/Solo5-SPT engine probe now boots with static GMP and unchanged engine
source; it needs a trial-only Lwt build guard. This is not production target support.
See [host feasibility evidence](docs/VERIFICATION.md#linux-native-replay-and-mirageossolo5-spt-engine-bounded-trial-guard-required).
A synthetic Irmin block prototype now saves/reopens two generations across process/VM
restart, preserving the old image. Stock Chamelon failed that retention check; a trial-only
filesystem fix was needed as well as the Lwt guard. Not an adopted storage backend or
crash-durability result: [bounded persistence evidence](docs/VERIFICATION.md#irmin-block-persistence-bounded-two-trial-dependency-fixes-required).
Guarded larger-value retention, completed-I/O failure points, selected process SIGKILL and
offline copy/reopen controls now pass; host/power-loss durability and maintained fixes
remain open: [failure boundary evidence](docs/VERIFICATION.md#guarded-block-retention-interrupted-publication-and-offline-restore-controls).

## Product direction

The selected goal is a long-lived backend-neutral household application preserving LOAM
meanings, useful new value and maintainability, not a Lean implementation clone. Core,
Admission and Publication stay independent of particular storage/runtime technologies.
**Human-readable canonical evidence and data sovereignty come before physical store adoption.**
Versioned canonical text is the first candidate; **SQLite canonical adapter adoption is paused**.
Unix is the near-term validation runtime; MirageOS is an explicit future product goal, with
experimental support today. Requirements and roles belong to
[architecture](docs/ARCHITECTURE.md#properties-to-preserve), not a chosen grammar/filesystem.
An ignored [Unix/SQLite trial](docs/VERIFICATION.md#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification)
now passes synthetic save/reopen/history/receipt/conflict/interruption controls.
[Linux syscall/lifecycle controls](docs/VERIFICATION.md#linux-sqlite-syscall-failures-and-retained-journal-lifecycle-control)
also pass; a stock directory-sync error can be hidden by COMMIT success, so no permanent
adapter, canonical schema or durable Saved is qualified. These results remain comparison
assets, not defaults for canonical representation. SQLite may be a rebuildable derived index
only if a concrete consumer earns it; no second authority. Irmin and MirageOS/Solo5 trials
remain preserved, not immediate prerequisites. Runtime and store are separate axes.

A [minimal Persistence contract](docs/ARCHITECTURE.md#minimal-persistence-contract) covers
coherent reads, conditional publication and uncertain-result reconciliation. Aim for shared
save/restart/conflict/recovery scenarios with backend-specific fault hooks, not identical
physical failures or weaker durability meanings. The immutable engine remains Base + Zarith;
Any SQLite/store dependency stays outer and needs a separate adoption decision.
Qualify representation/identity/publication/
recovery/backup before household adoption, without waiting for all LOAM parity or reproducing
upstream files. See [architecture](docs/ARCHITECTURE.md#selected-product-direction).

Access goal: record and inspect household state from laptop, phone and AI chat through
one selected authority. Desktop Notty is preferred; Bonsai is an optional browser-UI
candidate for phone/desktop, not an adopted dependency. Clients collect/render, shared
application gates own meanings and publication; AI suggestions do not manufacture facts.
Remote access/authentication/API and UI implementation remain unqualified; see
[client direction](docs/ARCHITECTURE.md#client-access-direction).
Future Conversation/Voice/unikernel entrances must reuse structured application operations,
not enter Core or turn terminal text into an API. Diagnostic availability and qualified
partial reads are [design requirements](docs/ARCHITECTURE.md#structured-operations-and-diagnostic-availability),
not implemented health/recovery features; no audio/LLM/chat/Mirage-specific addition now.
A [bounded versioned-text read](docs/ARCHITECTURE.md#experimental-versioned-text-read) now returns
existing structured quantities, supplied premises/provenance or typed refusal, without CLI or
storage types in its pure API. It is a synthetic profile, NOT an adopted canonical format.
User now approved a private read-only LOAM comparison to ground the next household question,
without making Bakhlo a LOAM layout clone. Select the actual read revision first; ordinary tests
remain synthetic and originals are never written. Then compare Unix publication/recovery and
long-term synthetic cost before choosing physical store/index roles. Fixture v2 is only an oracle; no writer/index, AI/UI or Mirage feature.
[Handoff](docs/HANDOFF.md#next-bounded-implementation) owns next work; experimental runtime fixes
are not immediate blockers.

## Build and try

```sh
./tools/bootstrap
./tools/check
./tools/opam exec -- dune exec bakhlo -- --help
./tools/opam exec -- dune exec bakhlo -- check-movement \
  --effect wallet jpy -1000 --effect food jpy 1000
./tools/opam exec -- dune exec bakhlo -- inspect-current-fixture \
  examples/current-preview.fixture wallet jpy
./tools/opam exec -- dune exec bakhlo -- inspect-current-text \
  examples/ordinary-quantity.bakhlo wallet jpy
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

The new text example also yields `1000 - 10 = 990`, retaining its original description text
and explicit correction (dates do not pick winners). It supports ordinary Actual only and
rejects richer metadata/families; [grammar](text/input.mli) and [pure read API](text/read.mli)
state exact scope. Neither example is household authority or a recorded/Saved operation.

## Retained scope

- Single household user, initially local; eventual multi-device recording/viewing is the
  goal, not multiple canonical authorities. CLI remains the development/read entrance;
  Notty desktop preferred, Bonsai browser evaluation optional. No current UI/network/sync.
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
