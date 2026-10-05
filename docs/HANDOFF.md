# Handoff

## Current direction — data sovereignty, canonical text first candidate, MirageOS goal

After 07cd41f, user approved reordering the roadmap: preserve human-readable canonical
evidence and data/meaning/runtime sovereignty, keep MirageOS an explicit future product goal.
[Architecture](ARCHITECTURE.md#properties-to-preserve) owns the requirements; meaning, logical
representation, physical publication and runtime remain separate choices. SQLite canonical
adapter/package adoption is PAUSED; optional rebuildable indexes require a concrete consumer.
Versioned canonical text is the first candidate, not an adopted grammar/store. Unix is the
near-term validation runtime; MirageOS support remains experimental, not an immediate blocker.
All SQLite/Irmin/Mirage trials and counterexamples retained. No authority/data migration,
global install, public service, source-side rename reversal, dependency change or push.

## Current work style — native OCaml, no anticipatory harnesses

User requests removing the recent Python/test scaffolding and using native OCaml until
another tool/check is concretely necessary. Cleanup owner: only recent ignored read-review
code/generated executables, not originals or existing Core tests. D: no tracked Python;
P: earned native gates and historical comparison results; R: distinguish disposable code
from retained private bytes/results. Completed scoped code/build-artifact deletion; private
inputs/results preserved, existing native code/tests/lock unchanged. No new test/probe/runtime
or test-suite replay in that cleanup. Subsequent needed read work below is native OCaml,
not a port of the retired harness.

## Active quantity explanation / one-image questions

User approves synthetic stages 1-2: explain a quantity's supplied premise, contributing Effect
occurrences and correction path, and ask multiple coordinates of ONE admitted read image.
Owners: Application retains qualified path/cut provenance; Presentation formats existing typed
answers/evidence only; CLI plans all questions before shell acquisition and reads/admit once.
D: clean 5b0db1a/main 50, native reader and indexed query already exist; P: 160 expect/four cram,
whole-source/support gates, independent cut/lineage/Effect models. R: exact correction paths
(not root->terminal invented edges), answer-bound cut, multiplicity/net-zero vs unknown and
batch exit/refusal sequencing. Small derived-provenance accessors are consumed by this view,
not new Core ontology/answer bus, cached facts or authority. Revisit maintenance table: no
trigger for parser/ID/findexn consolidation or performance optimization.
Instruments: existing native checks/long-chain control plus a few focused expect connections;
no new framework/model/campaign/Python/generated payload or private data. Bound: explicit
synthetic input, existing Actual subset, all-source admission before any answer; no acquisition
qualification, writer/store/UI/AI/NL parser, clock, VM/proof/operational replay or dependency.
Mixed batches retain per-question typed results; exit 3 if any unavailable, else 4 if presence,
else 0; no quantity subtotal or partial-source salvage. Revisit live reads only with an explicit
human question/acquisition owner and separate coherent-capture qualification.
Continuation review: current worktree contains the path/answer-cut accessors and an
implementation-less explanation interface; ordinary check stops before tests at that module.
Stage 1 consumes these through a pure terminal view, including excluded lineages, exact
Event-local Effect positions/keys and stale presence touch (not an invented scalar).
Stage 2 extends the two explicit-file readers with optional `--explain` and nonempty coordinate
pairs; shared CLI planning/rendering owns only identical pair/exit mechanics, not reader meanings.
Reuse existing expect/cram owners; inspect the single acquisition/admission calls rather than
introduce a counting harness. No new model, dependency, private read or sibling build.
Stage 1 completed: native pure explanation preserves typed outcomes, actual traversal edges,
answer-bound cuts and Effect occurrences; three focused connections plus existing long-chain/
oracle/retention checks pass. Ordinary check (163 expect/four cram) and release @install pass on
macOS. [Verification](VERIFICATION.md#terminal-quantity-evidence-explanation) owns failures/limits;
[Architecture](ARCHITECTURE.md#terminal-quantity-evidence-explanation) owns the view contract.
Next is the separate CLI batch consumer; no live-original read follows from these results.

## Completed readability cleanup

User approves doing the useful cleanup now and recording evidence-based revisit triggers for
remaining items. Question/owners: make the entry document and OCaml layout easier to read
without changing meanings or the main dependency budget. D: clean 038a172, 184-line README,
672 tracked ml/mli lines >120 columns, no formatter, main exact 50; P: current 160 expect
cases/four cram suites, opaque role IDs and whole-source/support gates. R: formatter version/
closure, OCaml 5.3 syntax, literal/docstring/expect preservation and repeatability.
Instruments: shorter README + verification navigation, existing contract links, isolated
version-pinned formatter observation on a local branch, then existing native checks if adopted.
No new framework/Python/model/campaign, main lock change, global installation, CI requirement,
semantic refactor, operational read or VM/proof/storage replay. Formatting is a separate commit.
Bound: own tracked ml/mli/Dune files only, never scratch/third-party/data fixtures; main remains
OCaml 5.3.0/Dune 3.24.2/exact 50.
Completed: README 184 -> 68 lines, evidence navigation and related-work revisit gate below.
Optional ocamlformat 0.29.0 adopted after isolated native trial; main 50 unchanged, tool-only
39 selections. Five representative samples and all 137 tracked ml/mli files have identical
location-erased OCaml 5.3 ASTs (including literals/docs); changed-constant control refuses.
Existing 160 expect/four cram and release @install pass, formatter idempotent, payload examples
byte-equal. No semantic cleanup or new tests/framework; use `tools/format` only after optional
setup, never add it to normal-build requirements. [Development](DEVELOPMENT.md#optional-formatting)
owns setup/config; verification records closure failures/limits, not a new platform claim.

## Maintenance revisit decisions

Before a related change, pit checks these triggers; a trigger permits bounded investigation,
NOT automatic implementation or new dependency/authority permission. Record observed evidence,
benefit, semantic risk and do/defer decision in the task note. No periodic blanket cleanup.

| Item / current decision | Revisit trigger | Must preserve / decision gate |
| --- | --- | --- |
| Two internal `Map.find_exn` aggregate lookups: retained, not an input failure | Construction changes could break insertion/lookup closure, or a concrete simpler total representation is proposed | Inspect `open_relations`/`relation_discharges` owners; preserve ALL local checks before aggregates, original-order first refusal and positions, exact totals and immutable retained rows. Reuse relation/discharge models; no `None -> zero`, hidden panic replacement or new domain error for an impossible input. Change only if simpler or closure is actually at risk |
| Explicit empty command records in three decoders: retained | A source-field addition or repeated same-field maintenance produces actual drift | Review every profile's representable/unsupported families. A shared unadmitted command initializer is optional, not an admitted `Source.empty`; never silently empty new evidence or hide required per-adapter coverage review |
| Three parsers: distinct roles retained | A concrete shared lexical mechanism has identical byte/error semantics, or an entrance genuinely has no consumers | Share only proven mechanisms, not acceptance/support meanings; inspect CLI, examples, type clients and oracle tests before removal. Fixture v2 is still consumed by comparisons, not obsolete merely because a native reader exists |
| Explicit identifier implementations: retained | Repeated mechanical changes drift or newly required roles materially increase maintenance | A functor may preserve distinct opaque .mli types; no fundamental Account/Month ontology, normalization or public type equations. Prefer it only if simpler to read/maintain; reuse type-boundary clients |
| Reconstruction/caching/index optimization: deferred | Named consumer exceeds a declared CPU/wall/memory/history budget on measured synthetic 10k/100k shapes | First reuse the existing admitted query image across questions; query does NOT rebuild Actual. Separate parse/acquisition/source/group construction/query costs; preserve whole admission, independent cuts and generation/interpretation binding. .mli is a seam, not proof of cheap interchangeability |
| `Event_memory.events` traversal removal: no blanket migration to lookup | Profile identifies an unnecessary full traversal or storage representation changes for a concrete consumer | Lookup uses `find_by_id`; enumeration still retains source order/multiplicity and ALL retained/superseded checks. Never replace whole admission with requested-ID salvage |
| Verification-history split: navigation first | Finding a specific current qualification/counterexample remains difficult after summary links | Move evidence with stable links; retain scope, negative controls and durability counterexamples. Length alone is not a deletion criterion |

## Completed scoped native read entrance

Question/owner: decode one supplied current HouseholdImage into retained outer evidence plus
existing conditional quantity image, without Python/code generation or Core ontology changes.
D: fe5201d/main 50, selected upstream read owners unchanged; P: earned Actual/four-support gates;
R: UTF-8 character lengths, faithful row mapping and outer request/Event closure. Pure scoped
`bakhlo.loam_read` + explicit-file CLI consumer; no root discovery, fallback, recovery or writes.
Use only a few existing OCaml expect checks for NEW framing/mapping/refusal risks, not another
harness/model/campaign. All required profile sections/Actual rows qualify before any lookup;
unsupported settlement/families refuse. Other sections retained opaque, not full-world admission.
No dependency change, operational payload fixture, native filesystem capture, writer or UI.
Completed: native `Read.of_string` with retained bytes/opaque sections/origins and existing typed
query image, plus `inspect-loam-quantity FILE LOCUS MEASURE`. Core unchanged; three focused
existing-framework expect checks for new risks, ordinary `tools/check` and @install passed.
[Architecture](ARCHITECTURE.md#scoped-native-loam-input-read) owns scope/contracts. No original
or private-payload read in this increment; shell file I/O is NOT qualified native stable capture.
Revisit broader grammar/optional coverage only for a named consumer; no full parity requirement.

## Historical private read experiment — latest LOAM contract, no original mutation

User selected `tools/loam tui`, then explicitly requested latest LOAM interpretation despite
unfinished old-layout cleanup; user owns that cleanup/migration. Wrapper selects checkout-root
build/product, not the data-side CI pin. We inspected source only and DID NOT run/build it or
change pin/originals. Current-only HouseholdImage acquisition; no legacy/previous fallback.
LOAM remains sole operational authority; ordinary product tests remain synthetic, all private
copies/identities/text/amounts/results stay ignored and out of fixtures/commits/public logs.

Private comparisons, including a fresh capture after user cleanup, demonstrated one conditional
Exact/premise through existing Actual/four-support gates. OPERATION request -> retained Event
provenance was qualified OUTSIDE Core, never payment/group/Saved or implicitly retargeted.
[Verification](VERIFICATION.md#latest-loam-contract-private-conditional-quantity-experiment)
owns historical execution/limits. Per user request the Python and generated test/probe code
is retired; private input copies/results remain, not a runnable adapter or current authority.
Existing OCaml engine/tests/lock unchanged. Fresh data needs fresh read; no full-household
admission/numeric LOAM parity, original write/recovery, permanent codec/store/API or push.

## Completed read slice — explicit ordinary-Actual profile, structured answers

Question/owners before code: can a small human-readable versioned text document yield exact
quantity+supplied premise/provenance or typed refusal without a DB, runtime, terminal protocol
or invented household truth? Outer pure text reader owns lexical/profile/version errors;
existing Application gates own ordinary Actual/corrections/support; shell owns file acquisition
and rendering. D: 160af72/main 50, no canonical codec/store; existing query API already exposes
structured Exact/Known_present/Support_unknown and retained source/cuts. P: strict source/query
admission, independent quantity/touch/correction oracles and fixture tests. R: bounded grammar,
lossless quoted bytes, refusal staging and observable evidence connection.
Profile: ordinary Actual Events with explicit base dates, Event-local keys/anonymous Effects,
Event corrections/descriptions and all four quantity support families. Other facts/families,
validity revisions, Exchange/Reversal/relations etc are UNSUPPORTED here and must refuse, not
be filtered into this profile. This is a synthetic read experiment, not full-world coverage or
canonical household format/migration. Independently supply narrow oracle inputs; never project
a richer fixture into a successful empty-metadata document.
Instruments: public API/nearest parser/shell review; deterministic escaping/huge-quantity/
profile/truncation/admission/provenance tests, existing fixture as independent connection
oracle, typed public clients and ordinary package/engine-only/Lean-free checks as applicable.
No new dependency, generic parser/effect/answer bus, writer/index/cache, performance campaign,
SQLite/Mirage/UI/AI/voice/network implementation, VM/proof or operational data. Preserve Bakhlo
names/main lock; revisit before broadening profile, encoding or effectful publication.
Completed: pure `Bakhlo_text.Read.of_string` -> existing opaque query image, terminal-only
`inspect-current-text`, directly inspectable synthetic example; no engine/source-gate change.
Exact/presence/unknown and source/correction/description/cut connection passed, with whole-input
refusals and standalone typed clients. Mac ordinary/forced package/install/clean engine-only/
nonexistent-LEAN checks passed; main exact 50 unchanged. Linux/Mirage/VM/proofs not replayed.
[Verification](VERIFICATION.md#experimental-versioned-text-read-ordinary-actual-profile) owns
bounds and corrected harness failures. Profile is NOT canonical storage or a physical coherent-
generation protocol; original authority/trials stay unchanged. Next: bounded publication contract
and lifecycle comparison, not AI/UI or automatic profile widening.

## Historical clarification — step 1 only, no implementation in that step

Question/owners: can roadmap changes protect directly inspectable evidence and a meaningful
MirageOS future without letting backend convenience own household meaning? ARCHITECTURE owns
requirements/roles; HANDOFF next work; short entry-document links replace stale default routes.
D: clean 07cd41f/main 50, no main codec/store. P: strict exact engine/typed boundaries and all
retained storage/host evidence. R: text grammar/version/identity, namespace publication/recovery,
index need and long-term cost. Instruments: nearest contract/direction review and scoped doc/
link/anchor/preservation checks. Step 1 only: no codec/API/writer/index/benchmark/VM/proof/UI
implementation or qualification, no new model/campaign/ADR. Revisit before representation or
physical adoption; past tests/trials are not fresh execution. Next step remains synthetic only.

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
That audit's next-step recommendation preceded the current sovereignty/text clarification;
follow the current route above. No audio/LLM/chat/network/Mirage implementation/install.

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

The bounded synthetic read is implemented; [Architecture](ARCHITECTURE.md#experimental-versioned-text-read)
owns its limited profile/API, not a final format. Do not widen it to full Actual by filtering
or promote fixture v2/experimental profile automatically into canonical storage.

The private latest-contract read-profile usefulness check passed for one conditional quantity.
The scoped native STRUCTURED reader and explicit-file consumer are implemented. Next name a
human quantity/evidence question and its acquisition owner; stable/coherent native acquisition
must be earned before calling a live original read current. No Python/probe port, automatic
root/fallback/recovery or permanent omnibus compatibility/Core ontology by habit. Add checks
only for a concrete unresolved risk; preserve typed missing/unsupported/refusal. User owns
operational cleanup and changed data needs fresh capture. Retained publication/cost work below
follows that useful native read boundary, not immediate writer work.

1. Name the next bounded publication/lifecycle consumer and compare Unix text-authority
   publication/save -> close/reopen -> read/recovery against earned SQLite/Irmin controls. Define coherent generations, expected generation, request/
   receipts, admission BEFORE effectful activation, real ordering/completion and explicit
   recovery. Text files/rename/Git commit are not automatically durable Saved. Qualify parent/
   namespace lifecycle, cleanup, replay/conflict/uncertainty and information-preserving restore;
   no silent older-world fallback, implicit repair or new filesystem by default.
2. Measure bounded synthetic long-term cost (e.g. 10k/100k Events, explicit correction/group
   shapes): reconstruction/save/reopen CPU+wall time, memory and retained-history growth.
   Whole-history copying/rebuilding is not a settled production strategy. Use a small owned
   probe, not a permanent benchmark/cache framework or operational fixtures; optimize only
   measured seams while retaining admission/closure/support guarantees.
3. Decide physical authority/index roles from sovereignty, durability, maintenance and measured
   cost. Canonical text + optional SQLite derived index is the first candidate, NOT a chosen
   layout or necessary dependency. Indexes identify qualified canonical generation/interpretation
   version, rebuild only from qualified evidence, never become a second authority. Review exact
   dependencies before any adoption. Later MirageOS adapter reuses meanings/representation;
   its own durable storage/update/recovery gaps cannot weaken Saved or block Unix progress.

No main store/dependency adoption, Mirage/UI/voice/LLM/auth/network feature or operational
cutover in the read slice. Preserve main compiler/50 lock, Bakhlo names and all trials;
full parity is not required before a useful bounded read/record/recovery path.

## Earned state / outstanding limits

Engine baseline qualified on native macOS x86_64 and Ubuntu 24.04 x86_64. Latest increment
checked on macOS only; no new Linux/Mirage replay. Engine/decoder meanings and signatures
unchanged by layout cleanup; pure outer text/LOAM-input readers and terminal consumers
are qualified only within their named synthetic bounds. SQLite consumer stays ignored scratch.
Full normalized Actual, real recording, production representation/upgrade/retry/recovery/backup,
Scheduled/reports/UI/API are absent.
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

Ordinary tests/development remain synthetic; the current user-authorized read-only comparison
is the sole private-data exception, bounded above. Existing Lean LOAM remains sole household
authority. No original mutation/recovery or sibling modification/build/source copy without
separate permission/licensing.
Local commits allowed, no push/release/public issue/PR. Last verified remote main: 19e1842
(PR #2 rename); later local qualification commits are not pushed. Never commit tools/environments/generated
output/third-party trial source, disks, private logs or credentials. Use repository wrappers;
no global host configuration or dependency install follows from this direction.
