# Handoff

## Current direction — backend-neutral LOAM, Unix + SQLite reference first

User explicitly changed direction after a78b478. LOAM core, Admission and Publication
must not depend on SQLite/Irmin/Mirage/Solo5. Introduce only the smallest consumed
Persistence contract; Unix + SQLite is the near-term practical reference implementation
to build/qualify. Irmin and MirageOS/Solo5 remain experimental options, NOT removed and
NOT prerequisites for the reference product. Store choice and runtime choice are separate
axes. This supersedes the earlier standalone Mirage + Irmin-first sequence, not its earned
evidence. No operational authority/data migration, global install, public service or push.

## Latest audit — structured operations / diagnostic availability; no features added

User asked to preserve later Mirage/Conversation/Voice entrances, NOT implement them now.
Principle: "LOAM Core must answer household questions structurally, without knowing how
those questions were asked or how the answers will be presented."
Question/owner before deeper inspection: which current typed commands/answers/errors already
satisfy this, and what terminal/parser/global-admission coupling could obstruct diagnostics
or safely scoped degraded reads? D: 6673026, pure Base + Zarith engine, no production store/
Publication/health service; CLI currently renders text. P: opaque structured quantities/
presence/refusal APIs, closed whole-source admission, no guessed zero, physical/semantic
independence models, backend-neutral policy. R: concrete future operations, failure scopes,
partial acquisition/completeness and structured load/publication diagnostics. Instruments:
nearest .mli/implementation/Dune/entrypoint/test inspection, dependency/effects/text audit,
small contract/comment changes only if earned; reuse ordinary checks if code boundaries
change. No placeholder operations/health enums/partial-source weakening or generic bus.
Treat future operation names/health/reason labels as examples, not implemented guarantees.
Completed: nearest-owner audit found existing structured/pure boundaries sound; terminal
fixture composition and whole-source admission are the future seams, not reasons for a
large refactor. Three .mli comments clarified terminal responses/image refusal, with no
signature or executable change. Four-category findings and executed checks are in
[VERIFICATION](VERIFICATION.md#structured-operation--diagnostic-readiness-audit-no-new-features);
[Architecture](ARCHITECTURE.md#structured-operations-and-diagnostic-availability) owns the
future contract. No placeholder operations/health enums or partial-read implementation.
Keep SQLite reference work next; no audio/LLM/chat/network/Mirage implementation/install.

## Completed alignment — contracts/roadmap before backend implementation

Question/owner before edits: can one coherent-read/conditional-publication/reconciliation
contract serve SQLite reference and existing Irmin/SPT experiments without backend details
entering meanings or weakening uncertain/durable outcomes? Application owns admission/
publication decisions; outer adapter owns transactions, I/O, synchronisation and recovery.
D: a78b478; main engine already Base + Zarith with no persistence imports; no SQLite adapter
or shared backend harness. P: exact source/support/parser/oracles, guarded Irmin retention/
restart/conflict, 190 failed-call points, four SIGKILL/offline-copy controls; failure may
follow publication. R: minimal executable interface, versioned representation/request
identity and receipt semantics, SQLite closure/OS library, shared scenarios + fault mapping.
Executed alignment: README/ARCHITECTURE/DEVELOPMENT/current handoff and initial dependency
ADR reflect reference versus experiments; VERIFICATION records planned shared cases and
sqlite3 binding metadata only. Historical handoff chronology moved out of the current route
(Git/VERIFICATION retain it); no backend source or earned engine tests removed.
Instruments now: nearest contracts/dependency metadata, dependency-direction audit,
doc/link/status review. No new theorem/model/campaign for policy/plumbing; no package
install/schema/API implementation or VM boot in this alignment. Revisit when the first
concrete SQLite consumer fixes lifecycle/format/identity/fault scope. Prior locks stay fixed.

Architecture owns [minimal Persistence contract](ARCHITECTURE.md#minimal-persistence-contract)
and [reference/experimental separation](ARCHITECTURE.md#selected-product-direction).
VERIFICATION owns [shared scenario plan](VERIFICATION.md#backend-neutral-reference-direction-contracttests-planned)
and historical platform evidence. Current SQLite metadata is a preflight, not installation,
solved dependency closure, operating SQLite version, durability or reference qualification.

## Next bounded implementation

1. Name a synthetic one-generation save -> close/reopen -> read consumer. Derive a tiny
   interface from that consumer plus the existing Irmin experiment, not a generic database,
   filesystem, effect monad, branch/merge bus or speculative service framework. Keep outer
   acquisition/version/I/O failures structured and distinct from semantic unavailability;
   diagnostic inspection must not claim readable fragments are a complete admitted source.
2. Review sqlite3 binding/version, alternatives and actual solved build/runtime/OS cost;
   place SQLite dependency solely in the outer Unix adapter. Main engine compiler/exact
   quantities unchanged. Versioned bytes are one complete source/support/evidence image;
   fixture v2 remains a synthetic oracle, NOT canonical household schema by default.
3. Implement Unix + SQLite reference with explicit provisioning/open modes, expected-head
   transaction, admitted immutable generations and reconciliation of uncertain outcomes.
   Qualify synchronisation/settings, failure/close paths and stopped-copy restore before
   Saved; do not equate WAL, transaction success or readback alone with power-loss proof.
4. Factor common save/restart/stale/conflict/corrupt/interrupted/restore scenarios and exact
   engine assertions; map backend-specific faults below them. Current Irmin/SPT controls
   are reusable evidence but are NOT already a shared harness or equal qualification.
   Unsupported durable capabilities are explicit limitations, not skips reported as PASS.
5. Keep experimental adapters separate. No requirement to repair Solo5 barriers or adopt
   Chamelon/Lwt guards before the reference implementation can progress. Then a small
   useful input/save/query path, Notty, authenticated multi-device/AI; Bonsai remains later.

## Earned state / outstanding limits

Native macOS x86_64 and Ubuntu 24.04 x86_64 locked ordinary suite qualified. Domain/Application
and current synthetic reader have unchanged executable implementations/signatures (latest
change adds boundary comments only). Full normalized Actual, real recording,
production representation/upgrade/retry/recovery/backup, Scheduled/reports/UI/API are absent.
Existing semantic evidence belongs to interfaces/VERIFICATION/REFERENCES, not a file-layout
porting checklist; no whole-tree parity, handwritten refinement or external-truth guarantee.

[Guarded Irmin/SPT interruption evidence](VERIFICATION.md#guarded-block-retention-interrupted-publication-and-offline-restore-controls)
remains useful. Stock Chamelon retention fails; CTZ/Lwt scratch guards and Solo5's missing
durable barrier still block experimental Saved. No permanent fork/backend adoption; larger
workloads/torn sectors/full disk/host power loss/live or off-device backup remain unqualified.
Experiments stay private ignored scratch, not ordinary-build dependencies. VM STOPPED.

## Safety/state

Synthetic only. Existing Lean LOAM remains sole household authority; never inspect/copy
operational data or modify/build/copy sibling source without separate permission/licensing.
Local commits allowed, no push/release/public issue/PR. Last remote observation: private
main 8974041 (2026-10-03), not current equality. Never commit tools/environments/generated
output/third-party trial source, disks, private logs or credentials. Use repository wrappers;
no global host configuration or dependency install follows from this direction.
