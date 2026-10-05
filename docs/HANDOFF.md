# Handoff

## Current direction — backend-neutral Bakhlo, Unix + SQLite reference first

User explicitly changed direction after a78b478. Bakhlo core, Admission and Publication
must not depend on SQLite/Irmin/Mirage/Solo5. Introduce only the smallest consumed
Persistence contract; Unix + SQLite is the near-term practical reference implementation
to build/qualify. Irmin and MirageOS/Solo5 remain experimental options, NOT removed and
NOT prerequisites for the reference product. Store choice and runtime choice are separate
axes. This supersedes the earlier standalone Mirage + Irmin-first sequence, not its earned
evidence. No operational authority/data migration, global install, public service or push.

## Completed bounded continuation — Linux SQLite synchronization/failure boundary

Question/owners before VM/install/code: does stock native SQLite exercise its supported
journal/database/directory synchronization route, and how do real syscall-result I/O
errors classify/reconcile? Outer SQLite adapter owns effects; pure admission/publication
seam remains backend-neutral. D: main 0fc0937/new Bakhlo names/main 50; isolated VM stopped
and named macOS trial retained. P: prior complete-generation/receipt/replay/failure oracles;
no durable Saved claim. R: moved VM launch paths/isolation, Linux binding/OS-library closure,
actual sync ordering, EIO/FULL/cleanup behavior, provisioning/restore boundaries and declared
completion assumptions. Instruments: named new ignored guest/host trial, unchanged current
engine/decoder digests, exact native closure/runtime inspection, syscall trace plus targeted
fault-result injection and cold reconciliation; existing ordinary checks only as relevant.
Use approved scoped HOME/LIMA_HOME/no shares/agent/public forwarding; no old trial disk
format/reuse, main dependency adoption, global host install, source semantics/schema
adoption, power-loss claim, UI/network entrance or optional proof. Revisit on actual sync/
cleanup errors; flags/trace/process restart alone cannot qualify device power-loss Saved.
Observed Linux DELETE journal creation-directory EIO is ignored by stock unixSync (COMMIT
can return success); post-deletion-directory EIO returns Uncertain with NEW receipt. Preserve
that counterexample. Bound one standard PERSIST-journal control with explicit checked outer
directory synchronization and retained journal namespace, no SQLite patch/custom VFS/fork;
it is not adopted production configuration or durable Saved.
Completed: current Bakhlo source/marker native replay, 73 DELETE + 76 PERSIST returned-syscall
faults, whole-family reconciliation, structured read-only recovery refusal, explicit recovery
on separate copies, stopped-family restore and graceful VM reopen passed. No SQLite patch or
main dependency change. [Linux evidence](VERIFICATION.md#linux-sqlite-syscall-failures-and-retained-journal-lifecycle-control)
owns exact outcomes/limitations; required directory sync/lifecycle cannot be inferred from
COMMIT success. Only guest development headers added at existing runtime version; main/guest
native 50 and reviewed outer 35 versions unchanged. VM STOPPED; original trials preserved.

## Latest bounded trial — Unix/SQLite save/receipt controls passed; Saved not qualified

Question/owners before code/install: can a thin OCaml SQLite adapter conditionally retain
one complete admitted synthetic generation + request receipt, reopen/query/history and
reconcile interrupted/lost acknowledgement without terminal text or SQLite in the engine?
Application owns admission/answers; outer orchestrator owns command/publication policy;
adapter owns SQL/resource/synchronisation effects. D: 930b3ac; no production adapter;
macOS x86_64 system/pkg-config SQLite 3.43.2 available, compiler/lock unchanged. P: exact
engine/source/support and Irmin retained-blob/failure oracles; typed operation audit.
R: binding source/solved closure and actual linked OS library, minimal consumed seam,
versioned trial envelope, expected-head/receipt/replay, structured failures, durability
settings/failure model. Consumer: fresh named synthetic store, save -> close/reopen ->
read plus stale/replay/history/uncertain controls. Assumptions/bounds: exclusive outer
process unless a named SQL contention control; full synthetic fixture bytes (NOT canonical
schema), explicit supplied request IDs; no clocks/household ID allocation. Instruments:
archive/source/license/isolated solve review; ignored trial only, frozen compiler/registry,
source digests, deterministic process/copy/fault controls and ordinary regression checks.
No new theorem/random campaign, global install, main dependency adoption, VM boot, UI/
voice/network, operational data/migration or Saved/power-loss claim. Revisit at concrete
receipt/encoding/durability faults or before main adapter/package/format adoption.
Completed: stock binding/source/closure reviewed and installed ONLY in ignored outer switch;
64 own source/build digests and main 50/lock unchanged. Small backend-neutral structured
read/publish orchestration consumed by SQLite; final save/reopen/history/replay/refusal/
uncertain/diagnostic/closed-copy controls passed, including invalid-current-evidence refusal.
No SQLite/CLI types enter its admission interface. Initial corruption-error classification
failure preserved and fixed. Actual native sync settings are recorded, not durable Saved.
[VERIFICATION](VERIFICATION.md#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification)
owns exact source/closure/control/evidence and limitations. No main adapter/format adoption
or common Irmin runner; no Linux/VM boot, new theorem/campaign or operational write.

## Latest audit — structured operations / diagnostic availability; no features added

User asked to preserve later Mirage/Conversation/Voice entrances, NOT implement them now.
Principle: "Bakhlo Core must answer household questions structurally, without knowing how
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
and historical platform evidence. That alignment's SQLite metadata was only a preflight;
the subsequent ignored native trial above now has source/closure/runtime evidence. Neither
step qualifies a production adapter/schema, durable acknowledgement or household adoption.

## Next bounded implementation

1. Fix the reference Saved failure model/maintenance owner: supported SQLite/VFS/OS sync
   ordering and completion, provision/restore directory lifecycle, close/cleanup and actual
   I/O-error handling. Linux sync/fault evidence above now earns one standard PERSIST plus
   checked namespace candidate, NOT an adopted policy or Saved guarantee. Qualify durable
   parent/provision/restore/activation and explicit hot-journal recovery/cleanup; reopening
   for writes may mutate before subsequently refusing lifecycle validation. No blind retry,
   implicit journal recreation or fallback. Admit input before effectful open/activation,
   not only before INSERT; current trial's handle-first shell is not a production entrance.
   Reuse earned controls, not a mandatory exhaustive
   power-cut campaign/proof. Fix declared OS/device completion assumptions before adoption.
2. Fix minimal production representation/version and store-scoped generation/request/receipt
   identity, retained candidate association, upgrade/export/restore rules before adoption.
   Trial fixture v2/SQL schema/request-derived tokens are NOT canonical defaults. Keep full
   source/support evidence; structured acquisition errors versus semantic unavailability;
   readable fragments/diagnostics never claim a complete world or permit implicit repair.
3. Then move only the consumed own adapter/orchestration/scenarios into a reviewed outer
   package/build. Binding 5.4.2 source + 35-entry outer closure reviewed; main budget/compiler/
   lock remain unchanged until an applicable adoption decision. No generic DB/FS service,
   effect monad, bus, new filesystem/runtime fork or SQLite in Domain/Application.
4. Map common logical controls to Irmin/Mirage's separate effect/fault runner without exposing
   SQLite or Solo5 mechanics to semantics. Current trial vocabulary/oracles earn a seam,
   NOT an already shared harness or equal durability. Unsupported Saved stays explicit.
   Experimental CTZ/Lwt/barrier fixes do not block reference progress. Continue toward a
   small useful CLI input/save/query/recovery path, then Notty; no full parity first, no
   new voice/LLM/chat/UI/auth/network or Bonsai exploration now.

## Earned state / outstanding limits

Native macOS x86_64 and Ubuntu 24.04 x86_64 locked ordinary suite qualified. Domain/Application
and current synthetic reader have unchanged executable implementations/signatures; SQLite
consumer is ignored outer scratch only. Full normalized Actual, real recording,
production representation/upgrade/retry/recovery/backup, Scheduled/reports/UI/API are absent.
Existing semantic evidence belongs to interfaces/VERIFICATION/REFERENCES, not a file-layout
porting checklist; no whole-tree parity, handwritten refinement or external-truth guarantee.

[Guarded Irmin/SPT interruption evidence](VERIFICATION.md#guarded-block-retention-interrupted-publication-and-offline-restore-controls)
remains useful. Stock Chamelon retention fails; CTZ/Lwt scratch guards and Solo5's missing
durable barrier still block experimental Saved. No permanent fork/backend adoption; larger
workloads/torn sectors/full disk/host power loss/live or off-device backup remain unqualified.
Experiments stay private ignored scratch, not ordinary-build dependencies. VM STOPPED.

## Main development environment after rename

PR #2/main 19e1842 source-side Bakhlo names retained; local path is /Users/user/Projects/moko/bakhlo.
Fresh main root/switch rebuilt with unchanged lock/compiler/50 versions; normal/package/install/
engine-only/Lean-free checks passed. [Recovery evidence](VERIFICATION.md#main-environment-rebuilt-after-bakhlo-directory-rename)
owns details. Old main environment archived at scratch/rename_recovery/bakhlo-env-v1, not deleted.
Trial DB/VM evidence unchanged. Outer trial switches/VM launch paths are not implicitly repaired
or newly qualified; handle their old paths only when a named future trial requires them.

## Safety/state

Synthetic only. Existing Lean LOAM remains sole household authority; never inspect/copy
operational data or modify/build/copy sibling source without separate permission/licensing.
Local commits allowed, no push/release/public issue/PR. Last verified remote main: 19e1842
(PR #2 rename); later local qualification commits are not pushed. Never commit tools/environments/generated
output/third-party trial source, disks, private logs or credentials. Use repository wrappers;
no global host configuration or dependency install follows from this direction.
