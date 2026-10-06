# Verification

Types, finite tests, models, proofs and operational evidence establish different things.
None automatically certifies handwritten OCaml, external premise truth or household use.
Ordinary qualification is macOS x86_64 and isolated Ubuntu 24.04 x86_64 with the locked
toolchain; bounded Solo5/SPT engine execution is below, not production support. Other
targets, storage, full normalized Actual admission, recovery and migration remain open.

## Find the relevant evidence

- [Canonical evidence review](#canonical-evidence--inherited-format-review): sourced retained
  information versus format debt; NO private-data inventory, codec adoption or migration.
- [Native Unix I/O failures](#native-unix-io-failure-boundaries): kernel-errno/returned-error
  connections, short writes, cleanup and complete-but-uncertain copies; NOT physical durability.
- [Closed synthetic backup/restore](#synthetic-closed-backuprestore): whole family/receipts,
  fresh namespaces, damage/lease/actual create collision/process-kill refusal; NOT durable Saved.
- [Synthetic TUI income](#synthetic-tui-income): explicit counterpart/receiver, mixed cold
  correction/history and uncertainty; old Bank/source remain unknown, no income total guessed.
- [Same-currency TUI transfer](#same-currency-synthetic-tui-transfer): mixed expenses,
  explicit endpoints, old Bank unknown, cold correction and detail-only IDs; synthetic only.
- [Synthetic TUI recording](#synthetic-tui-recordreopencorrection): BOTH native UIs,
  cross-language cold corrections/original history, uncertain receipt checks; no durable Saved.
- [Experimental Movement proposals](#experimental-ordinary-movement-proposals): new-row
  encoding/base preservation and whole-candidate refusal; not recording or storage adoption.
- [Friendly projected quantity answers](#friendly-projected-quantity-answers): typed narrowing,
  no raw provenance/input diagnostics in summary, not an auth/sandbox qualification.
- [Quantity explanations](#terminal-quantity-evidence-explanation) and
  [one-image CLI questions](#one-image-quantity-cli-questions), including answer-bound cuts.
- Current [native LOAM-input reader](#scoped-native-loam-input-reader) and
  [experimental text reader](#experimental-versioned-text-read-ordinary-actual-profile).
- [Engine tests, models and type boundaries](#retained-executable-evidence);
  [structured-operation audit](#structured-operation--diagnostic-readiness-audit-no-new-features).
- [Historical private read](#latest-loam-contract-private-conditional-quantity-experiment):
  results retained, retired probe code; not a runnable/current household acquisition.
- [Synthetic text scale/history cost](#synthetic-text-scale-and-history-cost): 10k/100k native
  phase/worker measurements, not an SLO, lifetime retention or storage adoption.
- [Native Unix text publication consumer](#unix-text-publication-consumer-synthetic-no-saved):
  synthetic record/select/reopen/correction and receipts, not durable Saved/store adoption.
- [Unix SQLite trial](#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification)
  and [Linux synchronization/lifecycle counterexample](#linux-sqlite-syscall-failures-and-retained-journal-lifecycle-control).
- [Guarded Irmin/block trials and limits](#irmin-block-persistence-bounded-two-trial-dependency-fixes-required),
  [interruption/restore controls](#guarded-block-retention-interrupted-publication-and-offline-restore-controls),
  [Linux/Mirage engine trial](#linux-native-replay-and-mirageossolo5-spt-engine-bounded-trial-guard-required).

These are scoped observations at their recorded revisions/hosts, not a cumulative production
certificate. Keep negative controls and counterexamples; do not erase history to shorten this
file. [Handoff](HANDOFF.md#maintenance-revisit-decisions) owns when cleanup is worth revisiting.

## Instrument review gate

Before non-trivial code, record a few lines in the task note/HANDOFF:

1. Observable question and invariant owner.
2. Deterministic facts (D), prior earned evidence (P), residual gap (R).
3. Chosen instruments or relevant deferral, with reason.
4. Assumptions, bounded checks, mapping/remaining gap and revisit trigger.
5. Actual execution/results, distinguished from planned or unrun work.

Select by risk, not directory or a per-slice checklist. Reuse independent models/oracles;
ordinary consumers test connection and failure boundaries. No mandatory all-tools pipeline,
new document, theorem or 10,000-case campaign for each change. User prefers direct native OCaml;
no new Python bridge or extra test harness without a concrete unresolved need. Existing native
checks remain available, not a reason to grow scaffolding first. A needed unavailable check
is a limitation/blocker, not silently replaced by compile success.

| Residual question | Instrument / trigger |
| --- | --- |
| What meaning/prior evidence must survive? | Semantic contract, narrow references, D/P/R review |
| Structural counterexample? | Small finite model/enumeration or Alloy; state scope and correspondence |
| Durable general law? | Optional Lean/specification with assumptions and mapping, not OCaml refinement by association |
| Procedure/authority ambiguity? | DRAKON for refusal/operation order, D2 for dependency/source topology; simple explicit code may suffice |
| Retry/crash/interleaving outcomes? | TLA+/TLC or SPIN when real write/failure contracts exist; targeted fault injection |
| Scale/cost uncertainty? | Named synthetic workload/benchmark; no universal inference or invented target |
| Duplication/dependency/security drift? | Focused repository audit with exact evidence |

Formal tools remain development-only. Ordinary build/test/release must be Lean-free.
Checker independence needs a separate question; neither standard Lean nor token scans
establish it. Tool selection does not authorize dependencies or source copying.

## Canonical evidence / inherited-format review

User requests reviewing LOAM's inherited shape before more prototype UI/store work. D/P/R,
instruments and privacy boundary recorded at clean c7da7a3 before detailed review. Read SOURCE
and docs only at clean sibling `f82f4c45498ce9b3c51a76acb7189588a5f74718`: operating mode,
blueprint/workbench/evidence map, then nearest authority/codec/projection owners. No repository
wide generated audit, new model/theorem/test/parser, upstream build/command/source copy,
operational/current-user payload/metadata inspection, private fixtures or format migration.
Maintenance table reviewed: no refactor now; future profile/field changes must reopen adapter
coverage. [Architecture](ARCHITECTURE.md#canonical-evidence--inherited-format-review) owns the
family classification and candidate boundaries; this section owns the source evidence/limits.

| Observed source boundary (paths under sibling `Loam/`) | Finding |
| --- | --- |
| `Authority/ActualAuthority.lean`: `actualPathFromRootOrFile`, `loadHouseholdObserved?`, `publishActual?` | Production root selects required Actual inside `household.loam`; explicit standalone Actual remains diagnostic/migration, never an automatic root fallback. Historical Actual lock identity remains explicitly temporary |
| `Authority/HouseholdAuthority.lean`: `knownSectionNames`, `qualifyKnownSections`, `publishObserved?` | 13 registered payload families; absent is not invented empty, known present bodies qualify, unknown/unmarked sections are preserved exactly. Observed-byte gate/staging/previous retention are publication mechanics, not household fact families |
| `Persistence/HouseholdImagePersistence.lean`: `encodeSection`, `decode?`, `body?` | Opaque payload length uses Lean String Unicode scalars, not bytes/graphemes. Absent != present-empty; duplicates/truncation/version mismatch refuse. Outer v2 numbering reflects research history; v1 never production |
| `Persistence/NormalizedActualPersistence.lean`: `encodeNormalizedActual?`; `Core/ActualEvidence.lean`, `Core/Settlement.lean` | Current encoder chooses v1-v4 by retained settlement/revision/extinguishment evidence. Actual carries more than current signed Effects; settlement quantity/Measure is independent of source-bounded RelationUnit. Old version numbers do not prove dead data |
| `Persistence/ScheduledLifecyclePersistence.lean`: `ScheduledLifecycleImage`, encoder/decoder; `ScheduledPersistence.lean` | Semantic occurrences + one typed terminal memory are serialized as four fixed substreams, including three former terminal kinds. Concrete simplification candidate in physical factoring, not deletion of completion/replacement/retirement distinctions |
| Registered Capacity/Attention/routing/role/Locus codecs | Explicit allocations, due/unknown/closure facts, historical Purpose routing, partial roles and NEW-write policy, rather than reconstructable report labels. Similar row shapes do not earn semantic merger |
| ZeroOrigin/OpeningSupport/CurrentQuantityAnchor/Presence/BoundedHistorySupport codecs; `Application/CurrentQuantityAnchor.lean`, `Core/BoundedHistorySupport.lean` | Explicit support/coverage, opening reference, assertion-to-cut ownership, presence without scalar, bounded-history claim. ASSERT is not a cached balance; opening quantity is already stored in Actual, not repeated in OpeningSupport. Anonymous group identity/order is unnecessary but cut ownership is not |
| `Core/MovementOperationEvidence.lean`; Bakhlo `loam_read/read.mli`/`input.ml` | Request -> original Event is idempotency provenance, not payment/chronology. Current native entrance qualifies it outside Core, retains other opaque sections and refuses settlement/unknown Actual rows rather than filtering richer evidence |
| `Presentation/MeasurePresentation.lean`, `Authority/MeasurePresentationAuthority.lean` | Exact quanta presentation/input scale is external metadata; changing a used Measure's scale requires migration. Missing-scale 0 is historical LOAM convention, not permission to infer a Bakhlo default. Other external configs remain unclassified |
| `Review/ActualJournalProjection.lean`, `Cli/JournalExportCli.lean`, `Export/BeancountExport*.lean` | Only correction-aware current Events/dates/descriptions reach export; plain journal omits Effect keys too. No support/history/policy codec. Beancount Open dates are scaffolding; projection is one-way, not information-preserving canonical extraction |
| Upstream `README.md`, `docs/BEANCOUNT_FAVA.md` versus current authority/export pipeline | Canonical filename descriptions/examples still show older standalone authorities. Source-selected current root route overrides these descriptions; no claim about deployed binary or user's selected data version |

Qualification is **source inspection**, not freshly executed LOAM tests/proofs or a private
usage census. Existing Bakhlo group/quantity tests and native-reader refusal/type boundaries,
plus upstream outer-framing/journal tests, were inspected only; no rerun was needed for doc-only
work. Two synthetic explanatory contrasts (different superseded history with identical current journal; same
assertion/Effects but different reflected cut) illustrate the already-earned non-reconstruction
boundary; they are not a new experiment/harness. No claim that hledger's full format/extensions
cannot encode this evidence: no hledger trial was run.

Confirmed costs: outer-length editing burden, old Scheduled physical decomposition, stale
canonical-path documentation/legacy entrypoints. Our trial's all-ancestor snapshot chain is
also not a household semantic requirement; preserving originals/receipts does not automatically
choose its physical layout. These findings are not evidence that all retained families are excess.
No family/field is marked operationally unused; no safe deletion, canonical encoding, frozen config bundle, extraction completeness or migration is earned.
Native reader's partial admission and text proposal's ordinary profile still block treating
those experiments as complete household representation. A coherent separately authorized
private sample is needed for actual family/metadata use and next representative format choice.

Selected source/docs (39 nearest owners) and revision/status recorded as digests in ignored
`scratch/canonical_evidence_review`; no upstream implementation copied there. Scope checks:
all selected owner hashes/revision/clean source status unchanged, Bakhlo lock/exact 50-package
set unchanged, tracked executable/interface/test files untouched, new local documentation links
and whitespace checked. No main/compiler/test result is inferred from this review; prior
native qualification remains scoped to its own increments. No dependencies, UI/store/format
adoption, parser/source changes, real recording, recovery, cleanup, publication or push.

## Native Unix I/O failure boundaries

User approves synthetic failure review. Owners/D/P/R/instruments recorded at 27de66d before
changes; previous sources/images retained in ignored `scratch/tui_comparison_review/io-v8/baseline`.
Existing Store/Backup/Recording implementations, engine and support meanings are UNCHANGED.
Both native consumers gain only consumed test-only connection commands before TTY acquisition;
dedicated `io-v8-` scope is checked before payload/fingerprints, publication checks require a
fresh empty synthetic store, and malformed expectations/operations refuse before effects.
Renderers, normal interaction, defaults and publisher checks remain unchanged. A small ignored
Darwin C interposer, built by existing clang with fatal warnings/no new package, is loaded ONLY
in named child invocations. Exact explicitly fresh trial paths and call occurrence select each
error; exact stderr/exit and hit log are required, not an untriggered environment flag.

Native kernel-error controls are deliberately bounded: fsync(-1)/close(-1) return EBADF; the
close probe first successfully closes the owned handle. Child-only temporary RLIMIT_FSIZE=7
and SIGXFSZ handling, restored before return/logging, produce a genuine 7-byte short write then
EFBIG. An existing publication checkpoint removes ONLY that fresh test's prepared head temporary,
so actual rename returns ENOENT while original CURRENT/evidence remain. These are NOT storage
media errors. EIO/ENOSPC are explicitly injected libc return values; partial-space controls
perform a real 7-byte write before injecting ENOSPC. No host disk filling, mount/VM/global
settings, new dependencies, Python, device/capacity or power-loss experiment.

Scope-qualified `io-v8/v3` passes 70 selected paired cases (64 failure + six short-write success):

| Existing owner | Cases, both consumers | Observable outcomes |
| --- | ---: | --- |
| Store -> Recording | 24 | Generation short/error/sync/close, paired cleanup, namespace sync before/after selection, head close, rename, lease close, genuine missing temp; OLD/NEW receipts, retained/frozen pending draft, no blind retry, original bytes/support and cold interruption |
| Backup capture/copy | 26 | Source read+close, parent/target sync, partial write/EFBIG, file sync/close, seal partial write/close, lease close; pre-effect refusal or post-start Uncertain, unchanged source, partial seal refusal, complete ambiguous artifact independently verifies, repeat refuses |
| Restore copy | 20 | Marker write/sync/close, parent sync, file close, CURRENT sync, pre-removal namespace sync, marker unlink and final namespace sync; incomplete cold load refuses, complete marker-blocked target refuses recording, post-removal complete-but-Uncertain target independently reads, all targets refuse overwrite/resume |

Paired primary/cleanup failures retain BOTH causes. Copy failures exit 1 pre-target/3 after
start with empty success stdout. Native connection commands exit 0 ONLY after independently
checking the intended failure, original-byte retention, quantities/support, read-only receipt
resolution and blocked submission. Short-write-only controls keep writing until complete;
whole exact copies/proposals survive. Fresh nonmatching probes in BOTH consumers intentionally
fail that expectation (exit 1, no hit/no success), not a false control pass. First v1 lease-close
probe incorrectly hit an earlier read-only Digest.file LOCK fingerprint; failure/source/image
retained. Selecting only the actual O_RDWR publisher/backup lease handle fixes the instrument,
not Store; fresh v2 passes and scope-qualified v3 repeats all 70 cases. Both scope/reused-root
and malformed-argument controls refuse without writes; final builds also pass the native errno
connection/smokes/exact proposal controls. Source LOCK capture still uses the same held descriptor.

A completed backup after seal close, final directory sync or source-lease close error can
verify without making the failed call successful/durable. Restore final-sync error AFTER marker
removal can leave a complete readable/writable-by-trial target, still Uncertain. No marker
recreation, automatic retry, cleanup, older-world fallback or inference of Saved. Original
source/archive fingerprints stay exact through faults, cold reads and repeated-target refusals.
Existing native mixed/history/180-bit/old Bank UNKNOWN, damage, Busy/lease and process-kill
controls pass; complete stock/Ox proposal bytes equal each other and the preceding backup trial.
Main raw `tools/check` passes 175 expect/four cram; main exact 50 names/versions, lock and
Store/Money/Workbench hashes unchanged. Physical PTY tests are NOT rerun for test-only entrances.
Sources/images/shim/raw main output/exit files/matrix/complete and refused artifacts remain ignored.

Retention review reuses current missing-ancestor/receipt/closed-set controls and previous scale
evidence, not another large workload. The tested mixed family retains 35 complete envelopes,
169,478 total envelope bytes, largest 8,976 bytes. Every selected ancestor remains a required
original/receipt/admission input; deleting it is corruption, not compaction. Decision: retain
ALL generations/originals/receipts and refused artifacts, no automatic pruning/cleanup or new
retention policy. This small observation is not a daily/lifetime capacity budget; existing
100k three-generation measurements do not qualify lifetime growth.

Remaining gaps: real ENOSPC/EIO/short-or-torn media writes, physical close-error descriptor
ownership (the probe deliberately closes it), host/device power loss/F_FULLFSYNC, creation of
ancestor parents, uncooperative namespace loss, explicit recovery/retention, other hosts/Mirage,
off-device backup/security and real recording. Stable cooperative parents and immutable archives
are still assumed; no main storage/format/UI adoption or durable Saved. Revisit before those
choices, not by broadening an errno campaign until green.

## Synthetic closed backup/restore

User approves synthetic backup/restore, not operational adoption. Owners/D/P/R/instruments
recorded before code at clean e581a6e; previous sources/binaries retained ignored in
`backup-v7/baseline`. BOTH native CLIs consume a small outer `backup.ml/.mli`: unchanged Store
family grammar, explicit scoped source/backup/fresh-target paths, no TTY or dependency needed.
Every selected ancestor's whole engine/UI profile and all closed regular files qualify before
target creation. Backup holds publisher-compatible source lease through exact capture/copy/
recheck; LOCK reads via SAME fd, never another descriptor whose close releases POSIX locks.
No source file-content/namespace writes, lost originals, reencoding, guessed support or fallback.

Backup-only seal is last: captured head + exact inventory/length/MD5, accidental corruption
indicator NOT authentication/security/durability. Restore requires nonexistent dedicated store,
own in-progress marker first/CURRENT last, copied full byte equality and whole source/profile
recheck before marker removal. Retained marker blocks Recording/UI publication; existing
store never overwritten/initialized/resumed. Source tokens cannot authorize restored namespace.
Uncaught process death retains artifacts; caught pre-target failure Refused/post-start failure
Uncertain. Failure has no success stdout. Completion before lost acknowledgement may be valid
on independent read, not proof of failure or durable Saved. No automatic cleanup/retry/cutover.

Both native recording consumers pass ALL prior controls and new closed-copy connections:
complete mixed family files/selected quantities/4 Measures/support/original date/route/memo/
corrections, original receipt != current with read-only reconciliation, fresh-namespace refusal
of source token, cold restored-only correction leaving source/archive unchanged, old Bank
UNKNOWN after income and exact 180-bit Bank income. Existing-target/repeated-copy refuses;
missing seal/ancestor, truncation, valid admitted same-length memo mutation, older head with
extra descendants, extra file, symlink, unsupported seal version all refuse before target
creation with no repairs. Unresolved source income orphan refuses, never becomes selected.
Cross-process publisher after ALL LOCK reads is Busy (lease retained); independently held
lease blocks backup without target creation. Source/backup fingerprints remain unchanged.

Native prewrite returned refusal creates no target; three backup post-effect returned errors
are Uncertain, partial seals reject/complete lost-ack seal verifies without Saved, never resume.
Actual new-target PROFILE-directory collision makes Unix open(O_EXCL) return EEXIST and yields
Uncertain/incomplete artifact; this is ONE actual syscall result, not EIO/ENOSPC/fsync/close
coverage. Returned restore error after CURRENT leaves marker/read-only UI with writes blocked.
Two real child SIGKILL controls after CURRENT copy retain unsealed backup and marker-blocked
restored store; no process-survival/power-loss/namespace/device guarantee inferred.

Actual quiet-drained PTY `backup-v7/pty-v2` passes five 100x25 children: Notty ja expense 10,
Wallet->Bank 100, Wallet income 200/Bank income 50 -> native Notty backup/Bonsai verification/
restore -> Bonsai en correct Wallet income to 250, inspect original, add EUR expense 12.34 ->
Notty source unchanged -> second Bonsai backup/Notty restore -> Notty ja correct original
JPY expense to 15/inspect original -> Bonsai ja/en cold reopen. Final twice-restored JPY Wallet
1135/Bank 150/Food 15, EUR Wallet 87.66/Bank 0; original remains JPY Wallet 1090/Bank 150 and
EUR Wallet 100.00. All five exit 0/full stty restored; shell wrapper read-only check and
restore-to-source refuse. First PTY Tcl parameter named `args` nested native argv, causing
argument refusal before backup; retained failure/source/reproduction, rename/fresh v2 passes.
Initial parallel stock build/main check hit Dune's lock, NOT a code failure; serialized stock
build/controls pass. Main `tools/check` passes (175 expect/four cram), exact main 50/lock/Store/
Money/Workbench unchanged; Locale remains pure Stdlib. Final native smokes pass; complete
stock/Ox proposal bytes identical to prior Tab trial, backup checks/restored answers identical.

Source/images/logs/closed archives/partial refusals/killed targets/final PTYs/hashes remain ignored
in `backup-v7`/trial scope. No user's current store or operational payload read/copied/mutated.
[Handoff](HANDOFF.md#completed-bounded-task--synthetic-closed-backuprestore) owns explicit commands.
Cooperative stable paths, immutable archive ownership and publisher-compatible lease assumed,
not a security sandbox or live/uncooperative/filesystem snapshot. Same-device experiment is
NOT off-device disaster backup; no encryption, real-data use, canonical store/UI/retention
adoption, original replacement/migration, cleanup/recovery, broad syscall/sync/close/space or
power-loss/durable Saved, other-host/Mirage/human IME/performance qualification. These remain
separate bounded decisions; an apparently complete selected file is not enough for recovery.

## TUI Tab order fix

User reports a visible navigation mismatch at Operation/Date (79beac5): BOTH renderers show
Kind -> Date -> Currency, shared Interaction advances Date -> Kind -> Currency. Scope/owners/
D/P/R recorded before code; retain initial Amount focus, layout, stored meaning and guards.
Added an independent literal visible-field witness to SAME native smoke: five routes x4
currencies x2 languages, forward/reverse/wrap/inverse Tab key dispatch, unchanged draft/bytes.
BOTH original-edge binaries fail that check. Corrected only shared focus edges; BOTH final
isolated builds/native smokes and existing geometry/amount/correction/unknown checks pass.
Complete stock/Ox proposal outputs agree; removing only the new success line yields exact
prior income proposal output. Workbench/Recording/Store/renderers/Money/Locale/lock hashes
unchanged; ignored `tab-order-v6` retains baseline/source/image/failure/result evidence.
No user-store read/write/init, dependency change, main test or new physical PTY/failure campaign,
storage/durability/operational/Mirage qualification. [Handoff](HANDOFF.md#completed-bounded-fix--tui-tab-order)
owns restart instructions; revisit if visible form fields/order change.

## Synthetic TUI income

User approves Income in BOTH existing native UIs. Owners/D/P/R/instruments recorded before
code at clean 10c7ec3; baseline sources/binaries retained in ignored `income-v5/baseline`.
Pure Workbench maps explicitly selected Income to `income-source` negative / Wallet or Bank
positive same-Measure ordinary Effects. No Core account/transaction-kind/party ontology,
provider/employment/tax metadata, source origin, income balance/total or support inferred.
Income activity does NOT establish missing Bank support. Both exact supported seed profiles,
init bytes/request, default store, original expense/transfer bytes, correction/currency/route
locks, whole-document refusal and existing Recording/Store owner remain unchanged. Locale
stays Stdlib-only; typed operation/destination collection shared, both palettes unchanged.

BOTH final native builds/smokes pass four currencies x2 receivers x2 display languages:
independently expected per-locus signed quanta, same-Measure two-Effect conservation/negative
counterpart, unrelated-currency invariance, exact 180-bit amounts, original date/amount/memo/
route, explicit source support UNKNOWN, amount/precision/currency/route/stale refusal and
three-operation/destination selection WITHOUT recording. Geometry checks retain original-history
room at 80x25 and small-view behavior. Complete stock/Ox controlled mixed proposal bytes agree
(40 retained Events/20 correction edges), not checksum-only equality. Initial stock compiler
refused `effect` as a 5.3 reserved test-variable name while isolated Ox 5.2 accepted; renamed
those variables without compiler or warning suppression, failed evidence retained.

Extended SAME native recording checks pass in BOTH consumers, retaining all prior expense/
transfer/currentness/receipt/refusal cases. Income covers all four currencies/both receivers,
cold bytes/original amount/route/memo/date (including 1900 correction, not inferred chronology),
non-last lineage selection, old Bank/source UNKNOWN after income, richer receiver/raw changed
correction route refusal, and cold 180-bit EUR Bank credit with Wallet unchanged. Synthetic
Generation-ready OLD/Selected NEW returned-error checkpoints retain exact frozen income forms,
block destination editing and reconcile read-only with unchanged file fingerprints. OLD stays
pending; NEW independently reloads selected Bank credit, preserving unknown source support.
No actual syscall/entropy failure or power-loss qualification follows.

Reused quiet-drained real PTY `income-v5/pty-v1` passes eight children at 100x25: Notty ja
expense 10 + Wallet income 1000/Bank income 500 -> Bonsai en correct both to 1200/600 plus
expense 20 and transfer 100 -> Notty ja correct NON-last Bank income to 650, inspect both
retained originals, refuse EUR 1.005 without rounding and record EUR Bank income 12.34 ->
Bonsai en/ja correct EUR to 15.01/inspect original/show-hide full detail. Final JPY Wallet
2070/Bank 750/Food 30; EUR Wallet 100.00/Bank 15.01; other currencies unchanged. OLD income
uncertainty/No receipt visibly remains pending in Notty, cold Bonsai interruption blocks
recording. NEW Bank income uncertainty visibly appears in Bonsai BEFORE Ctrl-R; receipt check
and cold Notty show Wallet 1000/Bank 25. All eight exit 0/full stty restored. ORIGINAL eight-child
transfer and nine-child expense PTYs also pass on fresh roots; no previous store reset.

Main `tools/check` passes (175 expect/four cram); exact main 50/lock, Store and Money hashes
unchanged. Final native recording/smoke checks pass. Same native-control and final PTY store
cold answers/generation/request/session bytes agree across stock/Ox consumers. Source/image
hashes, compile error, outputs, fresh synthetic stores and terminal traces remain ignored under
`income-v5`/trial scope; no current user's store or operational payload was read/copied/mutated.
[Handoff](HANDOFF.md#completed-bounded-task--synthetic-tui-income) owns launch/next actions.
No real-data use, FX/richer income categories, canonical store/UI adoption, migration, backup/
restore/recovery/cleanup, actual syscall/device/power-loss/durable Saved, human IME/grapheme/
resize/latency, other-host or Mirage qualification. These remain separate decisions/work.

## Same-currency synthetic TUI transfer

User approves Transfer in BOTH existing UIs and retaining their look with long internal IDs
moved to explicit detail. Owners/D/P/R/instruments recorded before code at clean 36ae42f.
Previous sources/binaries retained in ignored `scratch/tui_comparison_review/transfer-v4/baseline`.
No new main code/package/compiler/framework, storage layout, operational input or Mirage build.

Pure trial Workbench now maps Expense Wallet->Food and Transfer Wallet<->Bank onto EXISTING
two opposite anonymous signed Effects. One currency supplies BOTH Measures, exact positive
input/no FX; self-transfer refuses. Route is reconstructed from complete retained Effects,
not memo/translated label or a new Core transaction-kind/account ontology. Currency/route
changes during correction refuse at both form and direct Workbench entrances. Every retained
row, supported seed/support and correction edge still qualifies; no partial-row salvage.
Fresh explicit synthetic init adds Bank zero origins for all four versioned currency Measures;
older supported seed bytes remain readable unchanged with Bank UNKNOWN, never filled/migrated.
Transfer/nonzero/net-zero activity still cannot supply missing independent Bank support.

Both frontends share Kind/From/To collection, independent selectors and localized typed states.
Typed amounts and corrections cannot silently change operation/direction. Correction of a
non-last root now keeps its lineage selected rather than jumping to the final root (a concrete
connection bug found while adding mixed rows). Normal view omits generation/request/Event IDs;
Ctrl-G shows full identities, preserving draft/bytes/pending/receipt gates. Session diagnostics
retain full IDs; an ID is NOT a content hash, chronology or proof of durable recording.
Shared Locale remains Stdlib-only, no Unix/Async/widget imports. Palettes unchanged; compact
layout/geometry leaves original-history room at 80x25 in both languages/operations. No human
IME/grapheme/live resize/large-list/latency or permanent toolkit verdict.

Reused native pure smoke passes 4 currencies x2 directions x2 display languages: exact opposite
signs, independently expected per-locus quanta and same-currency conservation, unrelated-currency
invariance, cents/180-bit transfers, route/amount/memo originals, currency/stale/route/self refusal
and selector-vs-recording boundary. Complete controlled stock/Ox mixed expense/transfer proposal
outputs are byte-identical (24 retained Events/12 correction edges), not checksum-only equality.
Reused native recording checks pass in BOTH binaries: all prior expense/receipt/load/refusal
controls, JPY/EUR both-direction cold transfer/correction, mixed original bytes/date/route/memo,
non-last expense correction, normal/detail ID correspondence and original receipt/current reload.
Explicit older synthetic seed remains byte-readable with Bank unknown after transfer AND return
to net zero. Whole-admitted richer balanced multi-Measure shape and raw changed-route correction
refuse the UI profile. Transfer Generation-ready OLD/Selected NEW returned-error checkpoints
retain frozen exact drafts/routes; read-only reconciliation has unchanged file fingerprints,
OLD stays pending/NEW independently reloads BOTH endpoint quantities. Actual syscall/entropy/
power-loss failures are NOT injected or qualified by these connection controls.

Actual fully quiet-drained transfer `pty-v2` passes eight native UI children at 100x25: Notty ja
expense 10 + Wallet->Bank 100 -> exit -> Bonsai en correct transfer to 120, Bank->Wallet 20,
independent From/To picks/self-refusal and another deposit 10 -> exit -> Notty ja correct the
NON-last withdrawal to 25, inspect original reverse route, add EUR 12.34 -> exit -> Bonsai en/ja
correct EUR to 15.01, inspect original route/memo and show/hide full ID detail. Final JPY Wallet
885/Bank 105/Food 10; EUR Wallet 84.99/Bank 15.01; other currency quantities unchanged. OLD
transfer uncertainty/No receipt/blocked route displays in Notty, cold Bonsai interruption blocks
recording; NEW uncertainty displays in Bonsai BEFORE Ctrl-R, cold Notty reads Wallet 975/Bank
25. All eight exit 0 and full stty matches after canonical resume. Initial transfer `pty-v1`
FAILED a detail assertion because one-frame draining left older Notty frames queued. Retain its
trace/store; quiet-until-no-output draining fixes the instrument, not a relabeled UI failure.
The ORIGINAL nine-child expense PTY consumer also passes on freshly named synthetic stores.

Main `tools/check` passes (175 expect/four cram). Exact main 50/lock, Money source/policies and
original reuse Store hashes unchanged. Final native smoke/geometry/recording checks pass;
same-store stock/Ox cold quantity/generation/request/session outputs are byte-identical.
No current user's trial-store or operational payload was read/reset/copied; all controls use
fresh self-generated synthetic roots, and previous sources/images/trials remain intact. Sources,
images, native stores, failures, logs, PTYs and hashes stay ignored in `transfer-v4`/trial scope.
[Handoff](HANDOFF.md#completed-bounded-task--same-currency-synthetic-tui-transfer) owns launch/next
work; default store path stays unchanged, fresh Bank zero support requires EXPLICIT new init.
No real-data recording, migration, main canonical storage/UI adoption, recovery/cleanup,
backup/restore, actual failing syscall/namespace/device/power-loss/Saved, other host or Mirage
qualification. Broader routes, income and changing a correction's route require a new bounded
entrance/decision; no missing support may be guessed for product convenience.

## Synthetic TUI record/reopen/correction

User approves connecting BOTH existing native trials to the EXISTING ignored Unix text
publication consumer; bounded owners/D/P/R/instruments recorded before code at clean 492efde.
Current source/binaries/controls retained in ignored `scratch/tui_comparison_review/recording-v3/baseline`;
main exact 50/lock and `text_publication_reuse/store.ml/.mli` remain byte-unchanged. No new
package/framework/compiler, operational input, canonical store/layout, recovery or Mirage build.

Pure Workbench now prepares opaque proposals and reconstructs the WHOLE narrower synthetic
expense UI profile from an admitted document. Explicit original seed/support, every retained
expense's Effects/date/description and currency-bound correction path must fit; unsupported
rows, absent descriptions, old `jpy`, changed support or richer shape refuse wholesale.
Reopened trial Event allocation checks ALL retained identities; dates/root order are not
chronology. Ctrl-P cycles actual path originals with original ID/date/currency/amount/memo.
Locale remains pure Stdlib/no Unix/Async/frontend dependency. Shared display meanings do not
translate identities/memos or establish a universal keyboard convention. Broader language
switching/preferences/other UIs are deferred; this does not qualify a Mirage publisher.

A small consumed outer Recording owner symlinks/uses the unchanged Store. Explicit init only;
missing/invalid read never creates, repairs or falls back. Only dedicated trial-directory direct
children are allowed, root symlinks/outside roots refuse (cooperative stable namespace, NOT an
adversarial security service). UI publication retains current snapshot/base gates. Pre-effect
refusal, Conflict, Busy, mismatch, visible-unacknowledged selection and post-effect uncertainty
stay distinct. Success clears amount/memo to prevent immediate accidental repeat. Uncertainty
retains exact request/base/candidate and freezes edit/write; Ctrl-R reconciles read-only, then
separately reloads currently selected evidence. An original replay/receipt never becomes current
by itself. No receipt remains uncertainty, NOT failure or retry permission. Unexpected cold
files conservatively block writes without cleanup; selected evidence stays available, not empty.

Focused connection checks consumed by BOTH native binaries pass: 4 currencies x2 languages,
exact cents/signed 180-bit cold quantities, original bytes/8 Events/4 edges/date/memo, explicit
init/read-only scope/unsupported whole-profile refusal, failed reload/draft retention, stale
correction after refresh, Conflict, original replay after later correction and CURRENT reload.
Captured pre-write returned error leaves files unchanged/no pending result. Generation-ready
OLD and Selected NEW returned errors preserve form/model/uncertainty; no blind repeat. Read-only
reconciliation has identical before/after files; OLD/no-receipt and cold orphan block writes;
NEW/observed receipt independently reloads later selected correction if present. These are
connection/checkpoint controls, not new engine or syscall/power-loss qualification. Initial
native v1 conflict check FAILED: deterministic request IDs collided across sessions and yielded
mismatch rather than Conflict. Fixed with outer 12-byte Unix entropy request allocation; entropy
failure refuses and Store still checks collisions, not a production uniqueness service. Native
v2/v3 checks pass; initial failures/stores retained, not deleted or relabeled.

Real drained `pty-v4` traces pass: Notty ja EUR 12.34/memo -> exit -> Bonsai en reopen/correct
15.01, language switch, USD cent and ILS/JPY precision refusals/additions -> exit -> Notty ja
reopen/recorrect EUR 16.00 -> exit -> Bonsai en/ja cycles BOTH originals 12.34/15.01 and their
memos. Final wallet JPY 998 / EUR 84.00 / USD 199.99 / ILS 298.77, source checksum equal.
OLD uncertainty/No receipt/blocked edit visibly render in Notty; cold Bonsai shows read-only
interruption. NEW uncertainty visibly renders in Bonsai BEFORE Ctrl-R receipt observation;
cold Notty reads 990. Missing-store UI refuses before terminal acquisition, exit 1/no store
creation. Eight successful UI children exit 0; all nine full stty checks pass after canonical
resume. Earlier PTY v2 was functional-only (empty trace capture), v3 had undrained/coalesced
Bonsai transitions: preserve them, but only drained v4 qualifies visible intermediate warnings.
No IME/human editing/large-list/latency/SIGKILL/power-loss verdict follows from these traces.

Final stock/Ox pure proposal outputs and cold same-store quantity/receipt/session outputs are
byte-identical; checksums are observations, never an admission/currentness/security gate.
Main `tools/check` (175 expect/four cram) passes; exact 50/lock/source Store hashes unchanged.
Original paired/money/publication artifacts remain. TRY: `try-ui init` ONCE, then `try-ui notty ja`
and `try-ui bonsai en`; [Handoff](HANDOFF.md#completed-bounded-task--synthetic-tui-recordreopencorrection)
owns current launch/next work. Sources, images, hashes, logs, native stores and PTYs stay ignored.
Qualified ONLY synthetic native normal-exit loops and named controls on current macOS; no main
storage/UI adoption, live/off-device backup/restore, recovery/cleanup, actual failing syscalls,
namespace/device/power loss, durable Saved, real data, other host or Mirage qualification.

## Paired Notty / Bonsai_term synthetic draft UI trial

User explicitly requests trying/building BOTH desktop candidates, informed of OxCaml scope;
HANDOFF records question/owners/D/P/R BEFORE code. CURRENT 0438384 engine, Darwin x86_64.
Ignored `scratch/tui_comparison_review` now has TWO runnable native draft workbenches, not a
browser imitation, adopted UI or main writer. `workbench.ml` owns ephemeral trial Event IDs,
complete admitted documents/proposals and existing narrow exact/presence/unknown projections.
Shared `interaction.ml` owns the SAME tiny form/focus/list/scalar/paste controls, not household
arithmetic. Notty uses its own I renderer/Unix event loop; Bonsai_term uses its own View renderer,
typed event conversion, real Bonsai state machine and Async lifecycle. No copied old engine,
parallel model/oracle, Python bridge, protocol framework or generated payload. Both retain
original source/correction edges and never claim Saved; exit loses all ephemeral candidate work.

Dependency preflight: frozen default ac27950e5eac6c981ad809dff370c937820b7893; Ox registry
f1bd228dda31430bf6271f0f9adb2e604c6957ca. Direct Notty uses notty-community 0.2.4 to compare
the same family of renderer as Bonsai, not silently adopted main Notty. Isolated system-5.3.0
compiler aliases: nine baseline packages + seven additions, 16 actual total. Main compiler,
exact 50 versions/lock/dependency directions unchanged. Bonsai_term is pinned to source
2457232d3aa144fb887a053748a920544db60f72 / v0.18~preview.130.106+341; its closure conflicts
with Ox 5.4, so the isolated consumer uses OxCaml 5.2.0minus40 / Base v0.18 preview, 249 ACTUAL
installed packages including empty guards (initial simultaneous dry solve planned 254).
First solve timed out at 60s; one precise 120s retry succeeds, actual compiler/library builds
succeed. Current engine SOURCE SYMLINKS compile in that scratch-only Dune root without source
changes: NOT full main-engine qualification on another compiler. No OS/global install, main
lock/package changes, VM/Lean/operational inputs, canonical storage/UI/runtime adoption or push.
Trial trees ~8.7GiB, binaries ~4.6/53MiB stock/Bonsai: setup observations, NOT runtime memory/
latency/usability evidence. Both link native libraries only; pinned package/link/hash records,
source/build logs/export and failed controls remain ignored. No unreviewed cleanup.

Same controlled workbench checks pass in BOTH: synthetic wallet 1000 -> append 990 -> correction
985, retained byte prefix/original Event/memo and explicit edge; 180-bit positive quantity;
zero/exponent/invalid-date refusal without lost admitted draft; stale row refusal; scalar
Backspace, bracketed-paste control rejection/no implicit submit; known presence and unknown
not scalar/zero. Render width for Japanese '財布' is four; 80x30 and narrow geometry checked.
Exact complete stock/Ox controlled proposal/answer output compares byte-identically; observational
MD5 checksums are NOT a security/currentness gate. No new main tests/framework added by habit.

Real `/usr/bin/script` PTYs at 100x30 pass UTF-8 key input, Tab, Enter, Ctrl-E correction,
Ctrl-U replacement amount and Ctrl-Q in BOTH. Final wallet 985/source checksum identical;
child exits 0. Raw immediate `stty -g` probes v1/v2 report only lflag PENDIN 0x20000000,
not missing user flags: local SDK defines it as pending-input STATE; Darwin tty.c sets it
on canonical-mode restoration and ttypend() clears it when input resumes. v3 compares FULL
stty state after one normal canonical input: exact match for both (v4 repeats with final
source/image hashes). Non-TTY mode refuses in both with exit 1 and no answer stdout. Failed probes remain,
not a relaxed all-flags comparison or a patched vendor. The common launch shell owns terminal
restoration and propagates failure; SIGKILL/exotic terminals/OS-wide cleanup are unqualified.
These PTY traces inject already-converted Unicode, NOT actual macOS IME conversion tests.

Try from repository root in a real >=64x25 terminal, SYNTHETIC input only:

```sh
./scratch/tui_comparison_review/try-ui notty
./scratch/tui_comparison_review/try-ui bonsai
```

Quantity is initially focused: 10, Tab, synthetic memo, Enter; then Ctrl-E/Ctrl-U/15/Enter.
Ctrl-N new, arrows list, Tab/Shift-Tab focus, Ctrl-Q quit. Date is a visible fixed synthetic
value, not a hidden clock; quantities remain jpy quanta, no invented display-scale convention.
Ordinary main check still passes 175 expect/four cram; pinned format/whitespace and source/50
preservation checks pass. Choice stays OPEN: Bonsai ALSO has app-managed focus; no rich form
components, per-field incremental optimization/speed or more maintainable architecture inferred
from this small state machine. Human IME/keyboard feel, grapheme/cursor editing, resize interactions,
large-list performance, mouse/accessibility and persistent record/reopen remain next gaps.
No real data was needed; user feedback on BOTH is next, not automatic Notty/Bonsai adoption.

## Bilingual four-currency draft UI

User approves extending BOTH synthetic UIs with ja/en display and JPY/EUR/USD/ILS selection/
exact decimals; task/owners/D/P/R recorded BEFORE code at d865bfa. Human feedback: Bonsai looks
slightly richer (color/style), not a permanent choice or performance conclusion. Existing
paired source/image hashes and controls retained in ignored `paired-v1` before editing.
No dependency/compiler/framework/model/store changes: main 50/lock unchanged; same isolated
Notty/stock-5.3 and Bonsai/Ox consumers of CURRENT engine source, not another authority.

New ignored `money.ml/.mli` is a concrete text-to-quanta adapter, NOT balances or a currency
ontology. Explicit TRIAL policy announced: JPY 1 yen/quantum; EUR/USD/ILS 0.01/quantum. FRESH
Measure IDs `ui-money-v2:CODE:10^-SCALE` encode code/version/scale; old jpy is not recognized or
reinterpreted. Fresh explicit synthetic support: wallet JPY 1000, EUR 100.00, USD 200.00,
ILS 300.00, each food zero origin/pantry presence; no absent-data zero. ASCII stable loci have
ja/en DISPLAY labels, never translated identities. `locale.ml/.mli` renders closed typed UI
status/errors; memos/dates/quantities/currency are unchanged by language switch. No translation
service, global region defaults, Hebrew/RTL or main CLI localization is claimed.

Dot-decimal syntax in BOTH languages: JPY integer only; others 0..2 fractional digits (one
padded exactly). Positive expense inputs only; signed engine/answer quantities remain unbounded.
No float/rounding/grouping/trim/symbol/exponent/comma/sign coercion. Invalid grammar, excess
precision and nonpositive amounts have separate localized refusals. Too many digits refuse
EVEN trailing zero (`1.230`), not silently round. Currency switch refuses nonempty amounts or
ANY correction; direct Workbench correction also binds owner/currency. Start a new empty draft
rather than reinterpreting 12 as another currency. Entire document/proposals still use CURRENT
engine admission; UI never computes balances or invents support/FX. Rate/home-currency valuation,
production scale/catalog/store/format/migration/recorded receipt/Saved remain separate decisions.

Both native 4 currencies x2 languages smoke checks pass: append/correct, independently expected
integer quanta and unrelated-currency invariance; exact cents/signed display/180-bit decimal
roundtrip and engine quantities; old jpy refusal, invalid grammar/date/stale/currency refusal;
retained 8 Events/4 edges/original memo/base prefix; language preserves draft/bytes/memo, current
refusal relocalizes, unknown/presence stay scalar-free/not zero; paste no-submit and 4x2 renderer
geometry. COMPLETE controlled stock/Ox proposal/answer outputs compare byte-identically. Main
175 expect/four cram and pinned formatting/whitespace pass; original paired hashes/exact main
50/lock preserved. No added main framework/test campaign or alternate-compiler general claim.

Real PTY trace in BOTH starts English, selects EUR, enters 12.34/Japanese synthetic memo,
corrects to 15.01 with currency-change attempt refused, switches language mid-draft, adds USD
0.01, refuses ILS 1.005/JPY 2.0 without changing admitted quantities and then accepts 1.23/2.
Final wallet quanta JPY 998, EUR 8499, USD 19999, ILS 29877 (human 998/84.99/199.99/298.77),
same complete-source checksum; exits 0, full terminal state matches after canonical input resumes.
Bad language refuses BEFORE terminal acquisition, exit 2/no answer stdout; non-TTY exit 1/no
answer stdout. `money-v2` retains logs/source/image/link/package/lock/snapshots/PTYS. MD5 is an
observational checksum, not a security/publication gate. Actual IME conversion, grapheme/cursor
editing, rich widgets, live resize/long-list performance/RTL/other hosts/storage remain unqualified.

Launch `./scratch/tui_comparison_review/try-ui notty ja` or `.../try-ui bonsai en`. Ctrl-L toggles
language; Ctrl-K cycles currency on EMPTY new draft (Ctrl-N); Tab/Shift-Tab focus including
currency Left/Right; Ctrl-E correct/Ctrl-U clear/Enter validate/Ctrl-Q quit. Same original palettes,
no automatic framework adoption; compare both with human input next. No real data was accessed.

## Friendly projected quantity answers

User delegates small explicit household questions without a required AI/model. HANDOFF records
owners/D/P/R and bounds before code. `Current_quantity_answer.project` copies only the permitted
values/support family from an existing outcome; no lookup/arithmetic/source weakening. Japanese
Presentation consumes only this distinct opaque projection. Existing CLI `--summary` is the
concrete consumer; owner `--explain`/ordinary inspection remain separate. This does NOT implement
principal/coordinate authorization, a public protocol, sandbox, live capture or production service.

Four focused existing expect connections cover all exact support families/coordinate roles,
negative 180-bit quantity, known zero vs presence/net-zero-stale/unknown and owner-evidence positive
controls; native LOAM success omits request origins/keys/text/opaque sections, while six text and
seven native input-failure controls retain original 1/2 classes and no partial stdout/raw diagnostics.
Existing planner tests now cover competing/repeated views before acquisition. Existing cram tests
both CLI paths, Japanese 0/4/3 outputs, duplicates, unsupported/source/support/read errors, and
byte-equal inputs. Public scoped compiler clients accept the narrowed answer and reject forged
exact, raw-premise access, presence arithmetic and nonexistent source access. These check nominal
abstraction, not unsafe OCaml or hostile in-process/native code; projections remain sensitive.

macOS `tools/check` and forced package `runtest -p bakhlo` pass (170 expect cases, retained campaigns,
four cram), as does release `@install`. Optional pinned formatting passes; main compiler/50 lock
and dependency direction unchanged. A missing renderer result annotation made an error constructor
unbound, and one deliberately empty expect snapshot was filled after review. No warning suppression,
blind expectation promotion, new model/framework/Python/campaign/dependency, original data read,
sibling build, Linux/Mirage/proof/storage replay or recording/persistence qualification. Typed
unknown guidance remains a check suggestion, not a claim that the starting balance is missing.

## Terminal quantity evidence explanation

HANDOFF records the bounded continuation review. Application now retains exact admitted correction
paths and each assertion answer's owning cut; pure Presentation consumes them without changing
source/support gates or existing typed outcomes. Three focused existing expect cases connect
reversed declaration order/multihop paths, terminal keyed/anonymous multiplicity and Event-local
positions, independent assertion cuts (99/208), unknown/net-zero/presence versus explicit zero,
opening witness, 180-bit signed quantity and escaped exact identities. Cut correspondence reuses
the earned original-Effect oracle; existing retention helpers now compare paths too. The existing
10k-node lineage check additionally verifies every traversal edge in both declaration orders.

macOS native `tools/check` passes (163 expect cases, retained campaigns, four cram suites), as does
release `@install`; optional pinned formatting and exact diff/whitespace review pass. Initial
missing implementation, a test's nonexistent `Quantity.is_zero` name, and two deliberately empty
new expect snapshots were resolved; no admission weakening, warning suppression or blind promotion.
No dependency/lock change, new model/framework/campaign, private input, sibling build, Linux/Mirage,
proof/storage replay or live acquisition qualification. CLI consumption is qualified separately below.

## One-image quantity CLI questions

Stage 2 starts from clean d2b59f4 and the existing pure explanation/163 expect evidence. Both
explicit-file commands now accept optional `--explain` and one or more coordinate pairs. A small
CLI-only abstract nonempty planner/renderer shares identical pair/exit mechanics, not reader
profiles or Core meanings. Deterministic owner review confirms each shell branch plans ALL
questions before its ONE `read_text` call and each evaluator invokes its own `Read.of_string`
ONCE before batch rendering; no instrumentation harness or live-capture claim was added.

Three focused existing expect connections cover both planners' late-pair refusal/exact identities,
ordered duplicate/exact/presence/unknown results and 0/4/3 precedence in both mixed orders, plus
native explanations/whole unsupported/missing/source/support refusal. Existing cram adds both
synthetic read-only examples, Measure separation, duplicate rows, explanation paths/Effect keys,
late syntax before missing-file acquisition, whole-read refusal with no partial stdout and
byte-equal inputs. Single non-explained golden outputs remain unchanged. Terminal helper consumes
the existing typed outcomes once per question; no new quantity arithmetic or subtotal.

macOS native `tools/check` and forced package `runtest -p bakhlo` pass (166 expect cases, retained
campaigns/four cram), as does release `@install`. Optional pinned formatting, main installed count
50 and unchanged dependency/lock review pass. One test omitted Base's required `may_overlap` label;
a new deliberately empty expect snapshot was filled after exact evidence review. No source/support
weakening, warning suppression, new model/framework/Python/dependency, private data, sibling build,
Linux/Mirage/proof/storage replay or acquisition qualification. Fresh original reads still require
an explicit human question and separate coherent-capture owner/evidence.

## Readability and optional formatter qualification

User approved entry-document cleanup and evidence-triggered maintenance decisions, not DRY/
performance refactors. HANDOFF recorded D/P/R before code. README 184 -> 68 lines; navigation
links retain historical negative controls. Related-work triggers now cover invariant lookups,
empty commands, parser/fixture retirement, ID abstraction and measured reconstruction costs;
not an automatic calendar-based refactor or dependency permission.

Adopt **optional** ocamlformat 0.29.0, target 5.3.0, default/100 columns, no comment/docstring
rewrite. Separate ignored tool root/switch, frozen registry ac27950e5eac6c981ad809dff370c937820b7893,
39 selections, source archive sha256 dac77f0a957ae782bb4b869b07b9803a872a34f8c1eae8901b42d21b623c9db5
(MIT plus vendored LGPL exception). Main OCaml 5.3.0/Dune 3.24.2/exact 50 and lock unchanged;
no global/compiler/editor/CI change or vendor patch. Setup is tied to the existing local
compiler, not a newly bootstrapped platform closure. Initial borrowing attempts selected the
cached/global 5.4.1 and were honestly refused; incomplete compiler aliases then exposed global
`.opt`/Unix linkage and missing ocamlmklib failures. Complete ignored native-compiler aliases
resolved them, with actual 5.3.0 checks and vendor configuration validation, not version spoofing.
[Development](DEVELOPMENT.md#optional-formatting) owns the working recipe; no vendor-test claim.

Five representative Event/ID/LOAM parser/UTF-8 expect/interface samples passed unchanged native
AST comparison and repeatable layout. Reused the earlier OCaml compiler-libs AST instrument,
adding interface parsing in ignored scratch only: all **137** tracked ml/mli trees identical
with locations erased, including exact literal/doc attribute contents. Equal control passes;
changed constant refuses. This is bounded syntax-tree evidence, not household or formal
refinement proof. Dune-only whitespace diff reviewed; fatal policy/strict sequencing still
exercised. Long tracked lines >120: 672 -> 29; >200: 28 -> 0; remaining literals/comments are
not rewritten merely to meet a column count. Payload example hashes unchanged (synthetic only).

Formatter clean check/reapply and wrapper missing/wrong-version refusal passed; Dune's promoted
-diff exit 1 is accepted ONLY after a clean subsequent @fmt check. Main `tools/check` (160 expect,
retained campaigns/four cram) and release @install passed without formatter in the main switch.
No new framework/campaign, source semantics, operational read, Linux/Mirage/storage/proof replay.
One cached clean @fmt check observed 0.53s real / 0.12s user / 0.08s sys on this host; not a
cold-build or universal latency target. Setup paid the separate 39-selection download/build
and the explicitly retained retries above. Formatting stays separate from semantic refactoring;
tool upgrades need a representative review.

## Scoped native LOAM-input reader

Question/owners/D/P/R recorded before code in HANDOFF. New pure `bakhlo.loam_read` decodes
one supplied HouseholdImage v2 directly in OCaml; explicit-file `inspect-loam-quantity`
consumes retained input/origins plus existing opaque quantity image. [Architecture](ARCHITECTURE.md#scoped-native-loam-input-read)
owns scope and [interfaces](../loam_read/read.mli) refusal staging. Core, quantities, source/
support gates, manifests/lock/tools/compiler policy unchanged; no external dependency, Python,
generated OCaml data, new framework/oracle/model/campaign or operational payload fixture.

Three focused existing-ppx_expect cases address new risks: explicit Unicode scalar lengths
(two multibyte glyphs, combining scalar, four-byte scalar, NUL/opaque empty section), original
bytes/section order; direct mapping of every representable Actual family and independently
supplied origin/opening/assertion/presence/correction/date history; exact whitespace identities
and superseded request origins; 990/160/7/0 and assertion delta -10 with earned original-Effect
oracle connection, signed 180-bit quantity and v1 anchor lift. Typed read refusals for missing
coverage, settlement, repeated request, broken source, support overlap, duplicate section,
trailing/invalid UTF-8/truncated scalar extent and overflowing length precede lookup. Terminal
exact/presence/unknown retain 0/4/3 and stream separation. Existing CLI help golden updated.

Direct CLI file reads of the own synthetic LOAM-input example yielded wallet/jpy 990
(asserted 1000/delta -10) and food/jpy zero-origin 10; help/scope visible, no operational input.
Native library/CLI and `tools/check` passed on qualified macOS/OCaml 5.3.0: 160 expect cases
(three added), retained campaigns and four cram suites. Dev and release `@install` passed;
strict sequencing/fatal 8/9/11 preserved. Early test-only list/string producer mismatch,
Base stdout deprecation and expect indentation corrected, no warning suppression. No ordinary
OCaml dependency or Core change; no new Linux/Mirage/proof/storage/performance/private-data
replay. File reader is existing shell I/O, NOT native coherent/live/no-follow acquisition;
no household truth, full known-family qualification, migration/authority or durable Saved.

## User-authorized LOAM read-only metadata preflight

Pre-task question/owners/D/P/R and narrow permission exception recorded in HANDOFF/AGENTS.
Narrow source-only inspection of current and metadata-pinned read contracts found different
root-selection policies. Metadata shows competing authority files, not qualified complete
layouts or the actual everyday runtime. Stopped BEFORE household fact content/copy/query; no chosen current
world, new operational answer, corruption claim or unsupported-profile filtering.

An ignored own Python probe uses no-follow directory/file descriptors, regular-file checks,
strict revision syntax, before/after stat identity and repeated metadata-only observations.
Synthetic valid/invalid revision, unchanged read and symlink refusals passed. Private operational
metadata observation passed those stability checks; it does NOT establish atomic household
snapshot acquisition, backup/durability or all-file unchanged-content hashes. No original write,
entrypoint/recovery invocation, sibling build/modification/source copy or network operation.
Only policy/docs changed; engine/manifests/lock/tools/tests unchanged, no fresh executable-suite
claim. Public record omits private paths/hashes/identities/amounts; exact private observations
remain ignored, not fixtures or public provenance. This preflight stopped at selection;
the user subsequently resolved it and authorized the bounded continuation below.

## Latest LOAM contract: private conditional quantity experiment

User selected checkout-based `tools/loam tui` and then latest LOAM contract during unfinished
old-layout cleanup, which the user will perform themselves. Narrow source-only inspection
followed wrapper/CLI/TUI root/current-authority/persistence/support owners. No LOAM entrypoint,
sibling build/source copy, pin edit, original recovery/write/delete/migration or network action.

An own ignored reader acquired ONLY current HouseholdImage: no-follow directory/file FDs,
regular-file and explicit 16 MiB research bound, descriptor/path identity before/after, repeated
full-byte equality, exclusive private copy and final original-byte recheck. Copy/result access
restricted to private owner; exact hashes/paths/payloads not in public output or committed facts.
Synthetic framing controls exercised strict UTF-8, Unicode CHARACTER lengths (not bytes),
opaque unknown/empty versus missing sections, malformed/version/duplicate/truncated/trailing
input, symlinks and no old-file fallback. Stability is not atomic filesystem snapshot, durable
backup, all-private-file content isolation or security certification; reads may change atime.

Initial opaque inventory correctly refused OPERATION as unrepresented. Narrow source owner
identified one-to-one logical publication-request ID -> retained Event provenance, not payment
truth/group/transaction/amount or Saved. Own read profile represents and checks every such
mapping OUTSIDE Core (exact uniqueness, unique Event owner, retained-reference closure), retains
superseded mappings without transfer, and keeps full original opaque generation. All Actual
rows within this declared profile mapped without filtering; unknown/settlement/version/missing
profile coverage refuses. Existing whole source/four-support gates precede lookup. Other household
sections remain retained but unadmitted; no full normalized-LOAM/household qualification claim.

Synthetic compiled controls: older-dated explicit Event correction, exact cut/assertion and
original description bytes, stable links, duplicate/unknown mapping refusals, unsupported raw
families, signed 180-bit quanta, source-closure refusal and support-overlap refusal. Strict
sequencing/fatal warnings 8/9/11 preserved. Then the private candidate passed all read-profile
gates; one question chosen from explicit supplied support returned typed Exact with premise
and exact decomposition matching independent original-list correction traversal/integer Effect
summation. Private values/identities remain local; original current bytes rechecked unchanged.
This establishes a useful CONDITIONAL read-profile answer, not execution/numeric parity with
LOAM, external factual completeness, durable Saved, spending permission or production decoder
refinement. Changed data needs fresh capture, not stale answer reuse. No main module/API/test/
manifest/lock/tool change or ordinary-suite/VM/proof/storage/performance replay in this increment.

After the user reported authoritative data updated to latest, acquired a NEW current-only copy
under the same explicitly selected read contract (narrow source owners unchanged). Reused the
reviewed probes with new private artifact names, freshly replayed synthetic acquisition/profile/
compiled exact/huge-quantity/refusal controls before acquisition. New candidate again passed
whole read-profile source/support/provenance gates; one explicit-support question returned
conditional Exact agreeing with the original-list oracle. Original whole bytes AND identity
signature rechecked equal afterward. Previous artifacts preserved, not fallback/query input;
no inference that cleanup must change household blob bytes or qualifies full migration. Same
privacy/scope/no-write/no-main-change limits; no ordinary-suite/proof/VM/storage replay claim.

User subsequently requested removal of Python/anticipatory test scaffolding. Recent read-review
Python, generated OCaml payload/runners and compiled probe/control artifacts were deleted;
private inputs/results retained. Above records historical execution, not a replayable reader.
Existing OCaml source/tests/lock unchanged; no replacement harness or new suite run. Next needed
read path is native OCaml, not a translation of this retired pipeline.

## Experimental ordinary Movement proposals

Bounded question/D/P/R/owners recorded before code in HANDOFF at 2331eeb. Pure `text/Propose`
consumes existing reader/Movement/source gates; no Core/Application/CLI/filesystem change,
new dependency/model/campaign or whole-world codec. Only new explicit Movement/description/
correction rows are encoded into the already admitted ordinary profile; base bytes remain
unchanged around the insertion. A proposal is not publication permission or a selected snapshot.

Three focused existing native expect connections qualify: all 256 bytes together in ID/key/
Locus/Measure/description and signed 180-bit quantities, original ordered Effect multiplicity,
base lexemes/indentation/trailing whitespace and all four support families; correction keeps
old/new observations/edge/text and independent reflected cut (90 -> 80), chooses explicit edge
rather than later occurrence date and invents no support; staged unsupported-base/duplicate-key/
empty/zero/unbalanced/mixed-Measure/date/duplicate-ID/missing-or-superseded-target/opening refusals.
Explicit empty versus absent description stays distinct. Existing public type clients compile
without runtime/CLI/Presentation, reject forged candidate and read-image substitution. Unsafe
OCaml escape hatches are outside that check. The fixed-profile end locator depends on the
reader's earned complete framing, not a second parser or arbitrary text patch capability.
Initial compile errors (OCaml 5 `effect` keyword, fixture parentheses and misnamed accessors)
were corrected without suppressing warnings or weakening admission. Unix publication/lifecycle
qualification remains a separate ignored synthetic consumer; no durable Saved/full household/
operational recording/format adoption follows from these pure controls. Main macOS
`tools/check` (173 expect/four cram), forced package tests, release @install, pinned format and
whitespace review pass; installed set stays 50, no manifest/lock or inward dependency change.

## Unix text publication consumer (synthetic, no Saved)

Named consumer/owners/D/P/R/instruments recorded before code at 2331eeb; pure proposal qualified
in 3d0e0dd before this trial. Fresh ignored `scratch/text_publication_review`, native OCaml 5.3.0,
compiler Unix and EXISTING main Base/Zarith/artifacts only. No copied stale engine/switch,
third-party/upstream source, dependency/lock/global install, VM/Lean, operational data or main
store/UI/adoption. Dune excludes scratch; its actual workspace description contains no trial.

Disposable layout v1: explicit provisioning, permanent cooperative LOCK, atomically replaced
CURRENT pointer, immutable complete generation files carrying original parent/request and byte-
length-framed ordinary-profile text. Request IDs are explicit synthetic bytes (hex filename,
96-byte TRIAL path budget), not Event IDs/date/quantities or adopted allocation. Opaque tokens
bind canonical namespace path + generation; cross-store/restored-root token reuse refuses.
Assume single-threaded cooperative processes, stable exclusively owned namespace/parent path,
all writers taking the same retained lease and no mutation/deletion of retained generations.
Read captures ONE selected head and fully admits every required ancestor, never initializes,
repairs or falls back. Candidate whole admission precedes acquisition; complete stored admission
precedes write-open AND repeats under lease. Expected head is gated there, exact base bytes bind
the candidate, and new bytes are re-admitted rather than trusting preview. Generation file sync/
close -> checked namespace sync -> head file sync/close -> rename -> checked namespace sync;
provision also checks immediate parent sync. Caught errors after effects may begin, including
close/cleanup, remain Uncertain. No automatic deletion/recovery. No success hides a required
sync return; ordinary fsync is NOT Darwin F_FULLFSYNC/stable-media qualification.

Final native v3 controls pass: separate-process initial/select/reopen/correct loop 1000 -> 990 ->
985 with all four support distinctions/Measure separation, old source bytes/parents/Events/edge/
description and independent cut; exact 180-bit cold query + complete-byte round-trip. Stale
expected token conflicts, real two-process lease contention is BUSY (not Conflict), mismatched
base spelling/cross-root token/empty request refuse. Identical replay after a later correction
returns ORIGINAL receipt, not current/fresh; changed candidate/base refuses with unchanged file
bytes. Reconciliation only observes receipts on the SELECTED parent chain: complete prepared
files are not receipts. Explicit exact prepared-candidate retry works; changed prepared bytes
refuse, retained partial head temporary blocks retry without implicit cleanup. No-receipt means
not observed in that captured chain, not universal non-recording or permission for blind retry.

Eight named returned-error checkpoints report Uncertain/no success; cold processes and receipts
show 6 OLD/2 NEW. Two actual process SIGKILL controls immediately before/after head rename have
empty success stdout, OLD/NEW cold admission and unchanged reconciliation bytes. This is API-
checkpoint/process evidence, NOT syscall EIO/ENOSPC/short/torn writes, exhaustive kill timing,
host/power loss or device completion. Closed same-host complete-family copy preserves all bytes/
history/receipts and cold query; only newly captured namespace tokens may be used. Not live or
off-device backup/restore qualification. Invalid selected evidence blocks read/write activation;
unsupported layout, malformed header, truncated payload, dangling head, missing ancestor and
incomplete provision refuse without salvage, initialization, repair or older-world fallback.
Initial header review separated malformed corruption from unsupported versions; v1/v2 images/
logs kept and fresh v3 passed. Selected history is the declared admission scope, not every orphan.

Strict rebuild, source/image/linkage digests and v1-v3 controls retained in ignored evidence;
image SHA256 195f12763fa74b61c23476349f1bf69cc6daf9da68507d601bbb53a69c438f85.
Links existing GMP/libSystem only. Exact main 50 names/versions and lock SHA256 unchanged.
All trial child processes/handles finish/are waited; VM remains stopped. No canonical layout/
store/schema/production identity, full household/richer codec, principal isolation, valid-tamper
integrity, multi-threaded/malicious namespace concurrency, maintenance/cleanup/recovery service,
actual failing syscall/close controls, ancestor-directory lifecycle or durable Saved earned.
Whole-generation/history copy/reconstruction cost was UNMEASURED at this increment; the bounded
review below now supplies 10k/100k observations. Lifetime cost and production strategy remain OPEN.

## Synthetic text scale and history cost

Question/D/P/R/assumptions/review budgets recorded BEFORE code at 260950b. One disposable native
`cost.ml` consumer alongside the existing ignored Unix trial; CURRENT engine/Store reused, no
historical harness port or framework/model/random campaign/package/VM/Lean/operational data.
Host Darwin x86_64, Intel i5-8259U 2.30GHz, 16GiB; OCaml 5.3.0/Base/Zarith and exact main 50
unchanged. Native CPU/wall phase timers, `/usr/bin/time -l` worker wall/user/sys/peak RSS, three
fresh-process repetitions per ordinary shape. Filesystem caches UNCONTROLLED (likely warm);
no cache eviction, fresh-host, cold-media, other-host or universal latency claim. External
worker time/RSS includes start-up and correctness checks, not just the named timed phase.

Inputs: 10k/100k measured ordinary Events + TWO fixed USD/opening/net-zero-touch Events, two
ordered Effects each, Event-local key reused across Events, 1% supplied recognizer text. Flat
singleton roots versus disjoint four-Event/three-edge correction paths; replacement dates
older than roots, amount 1/2/3/4 so retained sums differ from selected terminals. Half-root
wallet cut with independently asserted signed 180-bit quantity; food/quiet origins, USD
opening, presence/unknown retained. Separate stress adds 100 independent empty-cut groups with
no matching physical activity. Native text producer is synthetic input, not generated OCaml
payload or a chosen canonical encoder. No failed/missing source becomes a successful quantity.

Ranges below are EXTERNAL worker seconds, three repetitions; input read/reopen v2 consumes
observable answer checksums, append/correct v1 operations are unchanged. Unsupported-input
negative control exits 1 with no CHECK PASS. v1 discard-only query loops were not accepted as
final query-cost evidence: v2 counts 572 Exact/143 presence/285 unknown plus exact checksum for
1,000 lookups, then checks expected original quantities; all source/reopen shapes rerun. Cached
image batch (INCLUDING checksum addition) takes 0.120-0.224ms here, not a per-question guarantee.

| Shape / measured Events | One input read | Append worker | Correction worker | Three-generation reopen | Largest lifecycle RSS |
| --- | --- | --- | --- | --- | --- |
| Flat / 10k | 0.11-0.57s | 0.61-0.64s | 0.88-1.00s | 0.36-0.38s | 88.8MiB |
| Four-Event paths / 10k | 0.12-0.14s | 0.68-0.69s | 1.02s | 0.39s | 83.8MiB |
| Flat / 100k | 1.01-1.05s | 6.43-6.55s | 9.46-9.53s | 3.63-3.64s | 759.2MiB |
| Four-Event paths / 100k | 1.21-1.23s | 7.59-7.65s | 11.23-11.40s | 4.23-4.25s | 765.3MiB |

Initial admit/write/sync workers: 10k 0.12-0.13s, 100k 1.16-1.37s, visible-unacknowledged only.
Representative 100k flat phases: acquire ~0.018s, decode ~0.356s, source ~0.385s, support ~0.255s.
Path source admission ~0.73s, support ~0.07s (fewer roots). Correction's read-before-proposal
~2.14/2.45s, proposal ~2.00/2.41s, publisher ~5.29/6.30s flat/path: repeated complete admission,
not indexed lookup, dominates. Each publication revalidates candidate and full selected history
before activation and under its lease; none of those gates were removed for speed.
100 extra groups: single sensitivity samples 10k ~0.77s/81.4MiB, 100k v2 ~8.52s/773.1MiB;
100k support phase alone ~7.69s versus ~0.255s, input adds only 4,390 bytes. Nearest owners confirm
per-group root-set/filter and original-Effect aggregation walks, retaining independent cuts.

Exact original bytes/three-generation parent associations/old recognizer text/correction edge/cut/current
selection/Measure separation/zero/presence/unknown checked after each operation and reopen.
Three complete snapshots occupy 3,708,370/4,203,370 bytes at 10k flat/path and
37,064,173/42,014,173 bytes at 100k (initial text 12,354,481/14,004,481). A small added Movement
still retains a COMPLETE new image; ~3x for three generations is NOT linear lifetime retention.
Unbounded publications, many-generation reconstruction, off-device backups/cleanup and storage
exhaustion are not measured or qualified. Entire retained test tree ~346MiB; original v3 sources/
image/digests intact, all cost source/image/raw logs preserved separately in ignored cost-v1/v2.
No trial enters Dune workspace. Ordinary check (173 expect/four cram) passes; lock and exact
50-name/version set identical. Process alarms 120s, observed-RSS stop 2GiB did not fire.

All EXPLORATORY review budgets (10k read 2s, 100k read 10s, proposal+publish 30s, RSS 1GiB)
met, not user SLOs/product readiness or Saved. Decision: defer main optimization/adoption until
concrete daily recording latency/group/retention requirements name the trade-off. Query reuse is
already earned; repeated whole admission and per-group walks/copies are the observed seams,
not license for partial admission, merged support meanings or speculative caching. Actual
returned I/O/sync/cleanup failures and namespace/power-loss lifecycle qualification remain
separate. Existing LOAM is sole authority; no real inputs were needed for this cost review.

## Whole-admitted document reuse and fresh publication gates

Question/D/P/R/bounds recorded BEFORE code at 8ea1cc9. User requests the measured save seam;
no canonical adoption/production writer follows. Pure `text/Read.document` seals original
bytes+EXACT existing query image via the unchanged complete Input -> Source -> Support gates.
`Propose.append_document`/`correct_document` reuse that base and still whole-admit ALL NEW
candidate bytes; raw entrances keep Base -> Event -> Movement -> Candidate refusals. Candidates
retain base/new documents, not recording permission/currentness. Two focused expect connections
check immutable old answers, identical raw/typed encodings, correction and new validity/opening
refusal; all prior byte/180-bit/multiplicity/cut controls remain. Public type clients accept the
sealed consumer and reject forged bytes/image documents and image-as-document substitution.
Unsafe OCaml escapes/principal isolation are outside this seam, just as for existing images.

Ignored `scratch/text_publication_reuse` is a versioned copy of OWN existing trial/consumer, not
a second engine, backend framework or maintained benchmark. Original v3/cost sources/images/
stores are unchanged. Actual PROFILE/CURRENT and every selected ancestor file are freshly read
before LOCK write-open; under lease all are freshly read AGAIN. Operation-local captured
admission is reused ONLY after exact canonical namespace/generation/FULL envelope-byte equality.
For a freshly validated envelope, identical complete sealed base/candidate document bytes also
reuse pure admission. Changed bytes get the complete normal reader, not partial filtering or
an older successful capture. No persistent/global/mtime/digest-only cache, inferred support,
cut merging, file repair/cleanup/fallback, new representation, dependency, VM/Lean or real data.
Expected selection/base/scope and original-receipt lookup still gate conditional publication;
they do not supply principal authorization.

Reused controls pass: 1000 -> 990 -> correction 985; retained bytes/text/cut/edge; Measure/zero/
presence/unknown, signed 180-bit quantity, original receipt replay/changed-request/base/conflict,
cross-namespace, actual two-process Busy, prepared-vs-selected, malformed/truncated/missing
history/layout and closed restore. Eight post-effect returned checkpoints remain Uncertain
(6 OLD/2 NEW), two real SIGKILL controls OLD/NEW, no success stdout and read-only reconciliation.
Ten NEW deliberate pre-lease interleavings check same-token changed bytes, invalid source,
changed-parent/same-body, cycle, missing selected, truncation, changed profile, valid concurrent
head, missing/invalid ancestor. All refuse or conflict with no further publisher changes;
Captured returned-error control is pre-write Error, not Uncertain. These synthetic mutations
are adversarial TEST changes, not qualification for malicious concurrency/stable-namespace loss.
A disposable negative binary OMITTING full-envelope equality fails the first same-token/new-byte
control (exit 1, unexpected publication effects); qualified binary passes. No production/cache
source was weakened for this control. Actual syscall/sync/close/cleanup errors and power-loss
namespace lifecycle remain separate: no Saved result, permission/security or recovery service.

Controlled comparison: byte-identical ORIGINAL cost inputs, unchanged native cost correctness/
checksum workload, fresh separate stores/workers; baseline is byte-identical original Store/cost
source relinked to the SAME CURRENT pure engine. Reuse differs only in typed-base entrance and
call-local publication reuse. 10k one paired repetition, 100k THREE (order reversed in repeat 2),
flat and four-Event paths. Full baseline/reuse retained store trees are byte-identical after each
lifecycle. Same Darwin x86_64 i5/16GiB/OCaml 5.3.0, uncontrolled likely warm filesystem cache;
not cold-media/user SLOs. Raw wall/CPU/RSS/phase/check logs and `summary.tsv`, source/image
hashes, package/workspace/link records and weak control retained under ignored `evidence-v1`.

| 100k Events | Baseline append | Reuse append | Baseline correction | Reuse correction | Reuse append / correction peak RSS |
| --- | --- | --- | --- | --- | --- |
| Flat | 6.69-6.70s | 2.42-2.45s | 9.96-10.10s | 4.54-4.75s | 409.8 / 561.5MiB |
| Four-Event paths | 7.91-7.99s | 2.83-2.86s | 11.86-12.00s | 5.44-5.54s | 429.6 / 584.5MiB |

10k append flat/path 0.63/0.72 -> 0.23/0.26s; correction 0.93/1.07 -> 0.43/0.49s.
Current baseline peaks flat/path append ~729/733MiB, correction ~945/979MiB. NOT directly the
old 8ea1cc9 RSS: raw proposals now retain their admitted base image as well as bytes; relinking
both variants isolates this from the reuse comparison. Reuse saves ~64% append/~53-54%
correction worker time. New candidate whole admission ~1.05/1.29s, not ~2.0/2.4s; representative
flat publisher ~1.51s vs ~5.29s in original review. Read-before-correction ~2.13s unchanged;
whole retained-history reopen ~3.7/4.3s unchanged. Capturing full envelopes adds reopen memory
(~11MiB flat/~28MiB paths vs paired baseline); original checks/consumed checksums still pass.
Three complete generations remain 37,064,173/42,014,173 bytes: no lifetime-retention improvement.

Decision: retain the small pure sealed-document seam and qualified TRIAL reuse only. Stronger
REVIEW hypotheses <=5s/<=512MiB are PARTLY met: append meets both, flat correction meets time
but not RSS, path correction meets neither. No lowering/relabeling those bounds or expanding
optimization/campaign now. Fresh-process history, per-group support walks and full retained
copies remain costs requiring a concrete daily workload/retention/host requirement. Main check
175 expect/four cram, forced package tests/release install/format/whitespace and exact main 50/
lock preservation qualify this increment; no operational-data read, storage adoption or push.

## Experimental versioned-text read (ordinary Actual profile)

Question/owners/D/P/R before code in HANDOFF. A pure outer `bakhlo.text` reader admits one
complete supplied byte string through existing source and four-support gates; no engine change,
terminal API promotion, runtime/store dependency or canonical-format adoption. Contract/grammar
owned by [Architecture](ARCHITECTURE.md#experimental-versioned-text-read) and `.mli` links there.
Fixture inputs supplied independently for this bounded profile; no richer evidence filtering.

Executed on qualified macOS x86_64 / OCaml 5.3.0 / Dune 3.24.2, unchanged exact 50 versions:
- Six new expect tests connect 990/160/7/0, abstract presence/typed unknown, original retained
  Events/keys/multiplicity/descriptions, explicit correction (older-dated replacement selected
  ONLY through the correction), forward references and three independent group/presence cuts.
  Independent fixture comparison and existing original-Effect Zarith oracle reused.
- All 256 escaped singleton bytes plus a complete all-byte payload through Event/key/Locus/
  Measure/description; literal UTF-8/space/nrt/quote/backslash, absent vs empty, no trimming,
  exact signed 180-bit quanta and anonymous multiplicity. Byte preservation is not UTF-8 validation
  or a production lossless encoder/round-trip certification.
- Reused 847 byte/sign/short-literal shapes, 68 token successes against independent digit
  arithmetic + explicit space/tab token boundaries. Different from the fixture's 42 field-byte
  successes: whitespace separates tokens here, never trims quoted identities/text.
- Version/profile, 13 unsupported record/comment shapes, 20 malformed frames/quotes/fields,
  every proper byte prefix of one complete escaped document, trailing evidence and CRLF refuse.
  Typed Input -> Source -> Support staging, duplicate Event/key, zero/unbalanced physical facts,
  missing/bad validity, dangling/cyclic corrections, equal-zero overlap and empty-cut closure.
  None/Some empty presence remain distinct; empty/unsupported lookup never becomes zero.
- New cram: standalone public reader client WITHOUT CLI/Presentation CMIs, unadmitted-input
  rejection and private lexer exclusion (three compiler specimens); Unix help/acquisition,
  exact/presence/unknown/version/profile/whole-refusal streams/exits and unchanged-file controls.
  Tests assume exclusive stable synthetic file ownership, not filesystem snapshot isolation.

`./tools/check`, forced package tests, local `@install`, clean engine-only build (no Text/CLI/
Presentation/bin targets) and ordinary check with nonexistent LEAN passed. Package and final
exact logs each contain 157 inline execution markers; ten existing campaigns/100,000 generated
cases and four cram suites retained/run. 84 prior compiler specimens + three new = 87. Main
installed 50 selections equal the recovered baseline; manifests/lock/tools/compiler policy and
Domain/Application unchanged. No operational data, SQLite/Irmin/VM/old trial mutation or new
Linux/Mirage/proof/performance/storage replay. Prior platform evidence is historical, not a
fresh qualification of the text adapter there.

Corrected before final qualification: `effect` is reserved in OCaml 5.3 (helper renamed), one
ambiguous doc-comment attachment, literal oracle initially assumed fixture field whitespace
rather than this profile's token separators, and two cram diagnostic expectations (quoted
module name / overlap wording). Public wrapper explicitly excludes the private lexer, not
merely omission of its CMI from test dependencies. Failed runs were not promoted as evidence.
Exact final logs/own scratch control remain in ignored `scratch/text_read_review`; initial RTK
logs retained privately. No new model/theorem/campaign/benchmark framework for this consumer.

Bounds: synthetic conditional ordinary-Actual profile only, not full household coverage,
canonical codec/writer/store/identity/upgrade, atomic filesystem generation selection, durable
Saved, diagnosis/partial-world service, parser resource/security/performance certification,
AI/UI or spending permission. Revisit before broader evidence/encoding or physical publication;
read success must not be promoted into recording or external factual truth.

## Backend-neutral reference direction (contract/tests planned)

After a78b478 user explicitly selected Unix + SQLite as the practical reference TO BUILD,
with Irmin/Mirage/Solo5 experimental and no technology-bound core/Admission/Publication.
Question/D/P/R recorded before alignment. Documentation/dependency-direction/metadata review
only in this step; no SQLite adapter/install/lock/schema/shared test runner/VM boot. Historical
Mirage/SPT evidence below remains earned, neither deleted nor qualification of this reference.
Architecture owns the minimal contract; tests must not call backend storage history household
corrections or turn unsupported durability into Saved. The later [bounded Unix/SQLite trial](#unixsqlite-synthetic-persistence-bounded-outer-trial-no-saved-qualification)
now exercises a concrete ignored consumer; the production adapter/shared multi-backend runner
remain to build, rather than SQLite still being wholly metadata-only.

| Planned common scenario | Assertion / physical mapping boundary |
| --- | --- |
| Save -> close/reopen -> read | Same complete versioned source/support bytes, exact 180-bit/zero/presence/unsupported/provenance answers; no mixed generations or stored derived balances |
| Expected-generation conflict | Atomic check/publish, no stale authorisation or auto-merge; BUSY/I/O error is not a fabricated conflict |
| Replay / uncertain result | Explicit operation/candidate association; identical qualified replay refers to original receipt, changed payload/base refuses; failed/lost response may have published |
| Corrupt/missing/unsupported format | Distinct load failure/absence, no init/default/drop/decode-to-None/older truth fallback |
| Diagnostic readiness / scoped availability (future host/partial consumer) | Structured faults remain accessible; missing support is not storage corruption. Unaffected answers require explicit qualified coverage/closure; affected answers unavailable, not zero/filtering/mixed generations. Not a current runnable service test |
| Interrupted publication / retained history | Old acknowledged state retained, complete selected generation or explicit failure; SQLite transaction/commit hooks versus Irmin/block hooks, NOT transplanting 95 API indices |
| Backup -> restore -> query | Declared stopped/live consistency and backup scope, exact bytes/history/support/answers; same-guest disk copy is not off-device/power-loss qualification |
| Durable Saved | Actual configured sync/order/receipt guarantees under named failure model; unqualified experimental capability remains a visible blocker, not a green skip |

First SQLite binding metadata preflight (frozen ac27950): sqlite3 5.4.2 (MIT), OCaml >=4.12,
Dune >=2.7 direct gates fit main 5.3.0/3.24.2. Requires dune-compiledb, dune-configurator and
build conf-sqlite3; with-test ppx_inline_test, with-doc odoc. System SQLite headers/library
remain external costs and actual version/configuration must be recorded. No transitive
closure/OS availability/compatibility/durability inferred from metadata. Named consumer:
outer Unix reference synthetic coherent snapshot save/reopen; thin bindings versus own C/SQL
FFI or an ORM/umbrella, with experimental Irmin retained. Review source/license/solved closure
and actual fault/recovery path before dependency adoption. Quantity never enters SQLite
machine integer/REAL arithmetic as authoritative quanta. Fixture v2 is not canonical schema.

## Structured-operation / diagnostic-readiness audit (no new features)

At 6673026, nearest owners inspected: engine Dune/.mli/implementations, CLI evaluator/shell,
Presentation and existing typed-client/application/query/decoder tests; pre-task D/P/R in
HANDOFF. User's future operation/health/reason names are examples, not added APIs.

| Finding category | Current evidence / bounded action |
| --- | --- |
| Already fits | Domain: Base + Zarith; Application: Domain + Base only. Movement_check.run is command -> typed preview/refusals; current quantity query exposes exact Quantity/Measure/coordinate/premise versus abstract presence/unsupported. Discharges expose conditional typed remainders. Rendering and actual I/O remain outside |
| Coupling to avoid | Current_fixture_command.evaluate turns read/decode/admission/query results into terminal Response; read failures and syntax details include strings. Synthetic decoder lives in CLI, whose library also depends on Presentation. Future canonical loader/shared operation must not inherit terminal exits/stderr or treat fixture v2 as storage/API schema; extract only for a concrete consumer |
| Real gap, not a defect to hide | Whole Actual/support gates refuse unrelated invalid evidence; decoder has no partial result and gates generally report first refusal. No diagnostic host, structured storage health or qualified partial-world operation exists. Scoped degraded answers need coverage/closure/generation qualification, not dropping failed rows |
| Small change now | Architecture distinguishes typed operations, diagnosis availability, partial-read guarantees and publication outcomes; three .mli comments mark terminal versus semantic results and image refusal versus host liveness. Declarations/executable implementations/locks/dependencies/tests unchanged |
| Defer | No placeholder Get* operations, generic answer/health/command bus, parser relocation, source-admission weakening, physical section schema, voice/LLM/chat/UI/Mirage implementation or dependency adoption |

Implementation lexical audit found no external-effect/formatting modules or explicit
mutation/raise/failwith in Domain/Application. Two Map.find_exn aggregate lookups consume
keys inserted for those SAME admitted rows earlier in the SAME immutable construction
(Open_relations/Relation_discharges); no fallback zero or new universal error added. This
inspection is not a purity/refinement proof or a guarantee that bugs/resource exhaustion
always yield structured diagnostics. Ordinary typed failures are not all possible host faults.
Clean native engine-only build passed with no compiled CLI/Presentation/bin artifacts;
./tools/check passed on the existing macOS lock, reusing earned campaigns/type/CLI controls.
No Linux/VM/Mirage/storage/proof replay or new fault campaign. This qualifies only current
boundaries/comments, NOT health-service startup, partial-read recovery or future operations.
Revisit with the SQLite representation/read-failure/publication consumer; expose structured
outer failures then, retaining faults and diagnostic inspection without false household truth.
Contract owner: [structured operations and diagnostic availability](ARCHITECTURE.md#structured-operations-and-diagnostic-availability).

## Retained executable evidence

Tests are executable documentation; names, seeds and counts live in the test source and
forced runner output, not duplicated status inventories. `./tools/check` runs all OCaml
checks. Existing generated campaigns retain independent expected-value logic and execution
counters; shared construction helpers are in `fixtures.ml`, never another test-case module.

| Seam | Independent evidence and limit |
| --- | --- |
| Quantity / Movement / application | Exact Zarith oracles, signed/huge values, replay and structural refusals; not publication |
| Effect keys | 81 four-Effect None/a/b patterns (21 admitted) against original-token-prefix oracle, exact spellings, Event-local reuse, physical generality, retained keys and anonymous controls for four supports; not metadata/overlay admission |
| Identity / correction / lineage | Original-list/fuel oracle and immutable integer Warshall closure; all 512 three-node and 65,536 four-node simple relations (73 admitted four-node paths). No missing IDs/parallel edges in enumeration; separately tested |
| Reflected cuts | List declaration model, 1,168 four-node relation/subset cases (304 cuts), selected fresh tails, prefix/source changes and old-terminal leak witness; not arbitrary-edit stability |
| Assertion arithmetic | 4,864 graph/cut/support cases, original-Effect Zarith sum, unknown/zero, translation and reflected/unreflected seams |
| Group ownership/re-observation | Independent two-coordinate/two-group list model: 256 construction and 2,304 update/replay seams; preserve whole premises, ordered refusals and old values; not durable retry |
| Event descriptions | 64 three-slot omission/a/b/unknown patterns (13 admitted) against original-token-prefix oracle; exact/empty/control text, retained source/order, permutation, correction-tail noninheritance, prefix requalification and four-support noninterference. Combined declaration-order duplicate/reference gate, not upstream refusal-order parity or text truth |
| Event merchants | 512 three-slot omission/provider-p/provider-q/nonmerchant/retained/unknown-Event combinations (52 admitted), original-token-prefix oracle and independent pre-code enumeration; exact/control/shared party IDs, general neutral Events, source/order retention, permutation, date/text/key/four-support independence with earned original-Effect arithmetic/touch oracles, correction-tail noninheritance, prefix requalification and immutable old source; not provider truth/coverage, a party registry or report routing |
| Exchange selection/source exemption | Independent original-token/list/Zarith model before product code and independent Python counts: 9,216 selected-Measure/sign/two-extra-Effect shapes, 122 selection / 74 nonzero source / 80 ordinary no-claim admissions. Curated selected-vs-net sign, third Measure, anonymous/missing/exact keys, duplicate/unknown/order, huge values, correction endpoints/open raw interference, retained payload/immutability and metadata/date/original-amount/four-support seams with earned Effect sum/touch oracles; no rate/fee/valuation truth or correction replacement. Existing 625 physical cases/generated tests also qualify private per-Measure arithmetic extraction |
| Actual Reversal | Independent original-token/list-remove-one physical multiset model checked before product code, independent Python counts: 7,225 two-Measure +/-1 length-0..3 pairs (289 exact / 9 ordinary source) and 273 four-ID 0/1/2-fact collections (37 globally disjoint). Model-only aggregate/regrouping/duplicate/coordinate counterexamples retained. Product correspondence, all 9,216 earned Exchange shapes with inverses (74 source pairs), reversal-side-only claims cannot rescue targets, reordered/key-free payloads, huge/control/zero/closure/refusal/replay/immutability; ordinary correction/prefix retaining original endpoints and current +1 counterexample, four-family independent cuts and cancellation-touch controls with original-Effect oracles. No factual truth/current universal cancellation, lifecycle/reporting/publication or arbitrary-size guarantee |
| Effect-backed relation units | Independent original-token/list/Zarith model checked before product code and Python counts: 40,401 two-slot ID/source/endpoint/quantity cases, 265 whole-family/source admissions. Explicit direction vs sign, equal-field independent units, opposite-direction/party overcoverage, same-coordinate different keys and cross-Event key reuse counterexamples retained. Product source/payload/index correspondence, exact/control/huge/zero/general Event, concatenation collision, ordered global-ID/local/aggregate refusals, immutable old source/replay/permutation/tail/prefix/omission; date/text/Merchant/original-amount/Exchange/Reversal/four-support seams with original-Effect sum/touch oracles. No arbitrary-size/refinement proof, external relation truth, target-local residue/completeness, discharge/remaining debt, lifecycle or publication |
| Closed discharge / snapshot remainder | Independent original-token/list/Zarith model checked before product code and Python enumeration: 5,776 two-slot Event/target/quantity/omission cases, 109 discharge/source admissions. Earned Relation_model premises; product raw/source/admitted/bucket/remainder order, full/partial/no-row/unknown and arithmetic correspondence. Curated exact/control/180-bit partial/full/over-total, source vs unrelated discharge Measure, typed-pair concatenation collision, empty occurrence/no Event budget, closure/self/duplicate/ordered/aggregate, replay/permutation/omission/target shrink/old-value immutability, corrected/reversed/noncurrent endpoints and prefix/earlier-date controls; metadata/date/Exchange/Reversal/four-support independence with original-Effect sum/touch oracles. No external fulfillment completeness, arbitrary-size/refinement proof, inactive-residue activation, write/crash/recovery or physical balance support |
| Original amounts | Earned integer Warshall pairs: 13 admitted three-node relations x 64 omission/negative/zero/positive declarations = 832 cases (44 admitted), independent pre-code enumeration and current lookup/order correspondence. Separate duplicates/unknown/guard-order/huge/control/Measure specimens, retained source, replay/permutation, fresh-tail projection and prefix/omission requalification; earned original-Effect arithmetic/touch oracles for four-support noninterference. Not amount truth/completeness, FX/basis or publication |
| Date history | Independent integer extension of earned Warshall model; 16,384 four-fact subsets/two-revision Event assignments/revision-only replacement relations (36 admitted), model-only counterexamples before product correspondence. Tagged-same-token IDs, revision-only evidence, retained invalid dates, ordered open/cross-Event/branch/merge/cycle/current conflicts, representation/tail/prefix/immutability and 10,000-revision chain/cycle; not arbitrary-size proof or temporal truth |
| Actual source / support routing | 625 two-Measure physical predicates; 16,384 two-coordinate/four-family seams (1,600 admitted), independent two group cuts/shared presence cut and original-list/Effect oracle; ordinary-source base-date inputs in that table; date-history/four-support noninterference tested separately |
| Explicit opening | Current/coordinate/duplicate closure, same Event for distinct coordinates, supported zero/huge signed multiplicity, representation/date permutation and stale-tail rebuild; retain original source/premises, no auto-retarget or historical truth |
| Presence | 1,024 three-Event/two-Measure touch/cut/declaration cases with ALL deltas zero (576 known-present answers), original Effect-membership oracle, selected vs retained activity, tail/prefix rebuilds, global stale overlap and retained premises; not historical/external truth |
| Origin queries | Original-Effect generated arithmetic transferred to the current admitted-source query; repeated payloads use distinct Event IDs, not implicit deduplication |
| Validity / decoder / shell | Calendar/reference counterexamples, exact tokens/quanta, unknown/obsolete/truncated/unsupported rows, escaped diagnostics, real CLI exit/stream and unchanged-file checks; no arbitrary corruption/authenticity guarantee |

Shared CLI quantity lexing is checked against independent byte/sign/digit arithmetic:
847 specimens (all eight-symbol strings of length 0–3, all 256 singleton bytes and six
zero/huge literals), 42 lexical successes. Both consumers retain exact values, original
syntax witnesses and their different neutral-zero/Movement admission. Not all strings.
Compiler-command cleanup retains all 48 client bodies, include scopes/options, expected
statuses and diagnostic assertions; positive/negative controls still execute. A one-shot
pinned compiler-parser check found identical location-free ASTs for four layout-only
implementations; this is representation evidence, not a new formal refinement proof.

Large chain/cycle and generated cases supplement, not universally extend, finite bounds.
External compiler clients test public abstractions, wrong qualified source types and private
arithmetic exclusion. Key/Event roles and unqualified/forged Events are rejected;
structural key refusal (exit 1) is distinct from syntax (exit 2). Merchant clients reject
Locus/party/Event role confusion, unqualified lists and incomplete disposition matching;
decoder/real CLI check exact forward references, equal/contradictory duplicates and dangling
Events (admission 1), malformed/misplaced/empty-party syntax 2, unknown quantity 3 without
support, escaped Event diagnostics and unchanged files. The combined per-declaration
duplicate/reference gate and nonempty practical party identity are declared upstream gaps,
not full raw-Core shape/refusal-order parity. Original-amount clients reject unqualified
Event memory, forged amount memories/current associations and original-to-current-quantity
conversion. Decoder/real CLI test exact forward roots/Measures/huge values, semantic
nonpositive/duplicate/unknown/non-root admission 1 vs malformed/misplaced syntax 2,
unsupported quantity 3, escaped root diagnostics and unchanged files. Practical per-row
ordering is not upstream separate-gate diagnostic parity.
Exchange clients reject Event-to-key confusion, forged memories, incomplete endpoint
handling and public Measure_totals access; decoder/real CLI test exact forward claims/keys,
missing/anonymous selectors, duplicate/unknown/third-Measure/net-zero/correction/zero-extra
admission 1 vs malformed/misplaced syntax 2, no-support 3, signed per-Measure outputs,
escaped provenance and unchanged files. Ordinary-only output labels were removed;
this is not full normalized Actual.
Reversal clients reject key/Event confusion, forged memory/pairs, pair-to-quantity conversion
and incomplete role handling; decoder/real CLI test forward exact endpoint facts, key/order
independence, earlier reversal dates, huge quantities, aggregate-only/regrouped mismatch,
open/reused/self/cyclic endpoints, nonzero and independently balanced target admission 1
vs malformed/misplaced/empty syntax 2, unsupported at net zero 3, escaped roles and unchanged
files. Diagnostic ordering is the declared local per-fact/pre-physical gate, not upstream
parity. No theorem was added or rerun; exact-list/source correspondence is bounded evidence,
not a proof of handwritten sorting/arithmetic refinement.
Relation clients reject Event/Relation-ID confusion, unqualified Event lists, forged memories/
positive views, positive-view-to-current-quantity conversion and incomplete endpoint handling.
Decoder/real CLI preserve exact forward IDs/keys/endpoints and huge values; resolve literal
External token HOUSEHOLD without guessing, reject duplicate/open/anonymous/nonpositive/
individual/aggregate/endpoint admission 1 vs malformed/empty/misplaced syntax 2, no-support 3,
escaped source/role/ID diagnostics and unchanged files. SETTLEMENT/PURPOSE refuse,
not silently discarded. Staged whole-family gate is not upstream diagnostic parity; no new
formal artifact/campaign or refinement/truth/operational claim.
Discharge clients reject independent Event-memory generation, Event/Relation target confusion,
forged whole/admitted/remainder views, remainder-to-physical-quantity conversion and incomplete
error matching. Decoder/real CLI preserve exact forward Event/Relation/huge quantities and
plain earlier empty Events; whole-source duplicate/open/self/nonpositive/individual/aggregate
admission 1 vs malformed/misplaced/empty syntax 2, no-support 3, all seven escaped error
variants and unchanged files. Former unsupported DISCHARGE witness became open-reference
admission control; malformed arity and unsupported settlement/purpose controls remain.
Closed acquisition is stricter than upstream target-local crash projection, not a replay of
its activation semantics. No new formal artifact/campaign or external truth/operational claim.
Description clients reject Effect-key/Event role confusion and unqualified lists; parser/real CLI exercise literal/empty
forward-reference text, duplicate/unknown admission 1 vs malformed/unsupported syntax 2,
no inferred support, escaped IDs and unchanged files. Date clients reject Event/revision
role confusion, forged history, omitted Revision handling and public cycle-helper access.
Reader/real CLI test tagged forward references, optional explicit bases/revision-only
sources, missing/ambiguous/open/invalid dates and admission 1 vs syntax 2. Existing Event
models/cycle witnesses qualify the private cycle-mechanism extraction. Clients reject
presence-to-quantity and incomplete outcome matching;
known-present 4 / unsupported 3 are separate real-CLI stdout outcomes. Unsafe casts/
internal-unit access are outside these guarantees.
`compiler_policy.t` checks complete controls and four diagnostic counterexamples in
both dev/release. Strict sequencing and fatal warnings 8/9/11 are not a purity checker.

## Qualification and limits

Normal checks, forced package tests, install and clean engine-only builds are exercised at
relevant semantic checkpoints. Engine builds must leave outer libraries unbuilt. Product
checks pass with nonexistent LEAN. Lock/tooling/platform changes require separate replay;
earlier fresh-switch equality is prior evidence, not a fresh replay for every code edit.

### Main environment rebuilt after Bakhlo directory rename

After PR #2/main 19e1842, compiled main environment retained old loam-ocaml absolute paths;
new switch execution failed with exit 50. User authorized archive/recreate, not path rewriting.
Old _opam/.opam-root/_build moved without deletion under ignored scratch/rename_recovery/
bakhlo-env-v1; task/evidence recorded there. Existing checked manager reused; ./tools/bootstrap
created a fresh root/switch at /Users/user/Projects/moko/bakhlo, fixed registry/OCaml 5.3.0 and
EXACT same 50 package names/versions. Manifest/lock/wrappers/manager hashes unchanged; compiler
stdlib/findlib/registered switch now use Bakhlo path. No source-side rename reverted.

Normal check, forced package tests (-p bakhlo), @install, clean renamed engine-only (no outer
compiled artifacts), final nonexistent-LEAN check and bakhlo CLI help/fixture quantity 990 passed.
Exact package/final logs contain all 151 inline-test execution markers; existing campaigns/cram
retained. Nested RTK/shell package outputs were incomplete (opam usage/empty log), NOT evidence;
raw exact commands were rerun with checked exit statuses. Bootstrap's unresolved release metadata
warnings remain, not fabricated authors/license. 58 synthetic SQLite file hashes and 12 VM file
metadata entries unchanged; archived main environment kept. No OS/global config, source/schema/
semantics, lock/compiler upgrade, optional proof, Linux/VM/outer-trial replay or operational data.
Historical outer switches/VM launch paths were NOT rewritten/requalified by main recovery;
review/recreate those only for a concrete later trial, preserving original storage evidence.

### Unix/SQLite synthetic persistence (bounded outer trial, no Saved qualification)

Question/D/P/R/assumptions recorded before code/install at 930b3ac. Named consumer: supplied
whole synthetic generation -> conditional save -> close/new process -> query/history/receipt.
Ignored scratch/sqlite_review only; no main package/source/lock, global configuration, OS
prerequisite, operational data or VM change. Official sqlite3-ocaml 5.4.2 archive checked,
SHA256 32f68f078f4beaed51ebc279fef46145205fd98cf6c79fe955218601f202621c; MIT source/API/
C-handle/statement/error and discovery review. Thin binding chosen for this trial over owning
C FFI/lifetime/error logic or an ORM/umbrella; no permanent dependency/format adoption.

Separate opam root/switch uses frozen ac27950 registry and EXISTING main OCaml 5.3.0 via
ocaml-system, not a fresh compiler/platform qualification. 35 installed outer packages,
including Base v0.17.3/Zarith 1.14/Dune+configurator 3.24.2/sqlite3 5.4.2; common package
versions match main. 17 outer-only names (including ocaml-system instead of main compiler):
sqlite3/conf-sqlite3, dune-compiledb 0.6.0 and its astring/fpath/ezjsonm/hex/cstruct/fmt/jsonm/
uutf/sexplib/parsexp/num/ocamlbuild/topkg closure. dune-compiledb declares LGPL-2.1-or-later;
SQLite OCaml library has no OCaml library dependencies and links native SQLite, not these
build-tool libraries. No Jane Street endorsement inferred. Main exact 50 packages/lock stayed
identical. Observed root/switch/probe/reference ~118460/83240/8784/572 KiB, not cost guarantees.
Native binary links /usr/lib/libsqlite3.dylib, existing GMP and libSystem. Actual SDK/vendor
SQLite reports 3.43.2, source ID ending 709aapl; pkg-config matches. It is not an independently
pinned upstream SQLite build. Extension loading is disabled by stock Darwin binding discovery.

64 own source/build digests matched current engine plus ONLY the synthetic decoder/quantity
lexer. No CLI/Presentation library linked; only fixture module namespace is used outside the
engine. Reused Irmin synthetic payload/oracle, not third-party/Lean source. Trial outer files:
run/{persistence.ml,publication.ml/.mli,sqlite_store.ml,main.ml,payload.ml}; run-controls.py.
The synchronous publication seam takes coherent-read/conditional-publish functions returning
backend-neutral structured values; source/support admission is separate from SQL and terminal
rendering. Current immutable generation is semantically requalified before the atomic SQL gate
(assumed exclusive trial publisher; legitimate head changes still conflict). No Core I/O/runtime,
dummy health/world, generic command bus, effect monad or household recording operation added.

Trial storage uses explicit provision versus READONLY/NO_CREATE open, application/version header,
STRICT generations/receipts/singleton head, foreign keys and immutable-row triggers. BEGIN
IMMEDIATE compares supplied expected head and stores complete BLOB + parent/request/receipt/
head in ONE transaction. BLOB preserves exact input, including NUL/quote/space/UTF-8 request
and recognizer text; no household quantity enters SQLite INTEGER/REAL arithmetic. Tokens derive
from supplied trial request IDs, scoped to this store, NOT production identity allocation or
household chronology. Fixture v2/schema v1 is a synthetic control, NOT canonical storage.
Exact replay returns the ORIGINAL receipt even with a newer current head; changed payload/base
refuses. Missing store/provisioned empty/version/corruption/busy/input/stored-evidence failures
stay distinct; no init, zero, older-generation fallback or blind republish. No-receipt means
only not observed at this read, not universal proof of non-recording. Resource/transaction
mutation belongs to the adapter; cleanup failure stays explicit.

Final controls-v4 passed: seed/new-process read/update/history; retained old bytes/parent and
180-bit/four-support/zero-versus-touch/unknown/correction/relation provenance/remainder 3->2;
stale expected head, identical replay, changed candidate/base, syntax/over-discharge refusals,
immutable-row checks and two-connection BUSY (not fabricated Conflict). Complete rich example
round-trips byte-for-byte, retaining eight validity facts/Exchange/Reversal; binary payload/
request/receipt control passes. Unsupported schema 99, damaged SQLite header and physically
valid-but-invalid stored evidence yield structured faults; invalid selected evidence blocks
publication. Read/refusal/reconciliation disk hashes unchanged; native process can report these
faults without a healthy household answer. Not an implemented diagnostic host or partial world.

Five synthetic failed-return checkpoints: after generation/receipt/head SQL, before COMMIT,
after COMMIT. All return Uncertain, no publication PASS; next process sees 4 OLD/1 NEW with
old generation and receipt retained. Two REAL process SIGKILL checkpoints before/after COMMIT
reconcile OLD/NEW with no success reply. These are named API checkpoints, NOT SQLite syscall/
sector/torn-write/exhaustive kill or host/power-loss controls. Closed DELETE-mode complete DB
copied to a separate same-host file; bytes/history/receipts/query match, no live/off-device backup.
Initial v1 corrupted-header diagnostic was wrongly classified as generic backend/open failure:
stock prepare raises Sqlite3.Error, so classification now occurs while handle/errcode exist,
not only for SqliteError. v1 source/image/disks/logs preserved; fresh v2/v3/v4 controls passed.
A publication-interface record-label inference mismatch was corrected with explicit snapshot
annotations; no engine/compiler/semantic weakening. No dependency patch required.

Every write connection checks journal_mode=DELETE, synchronous=EXTRA(3), fullfsync=ON(1),
foreign_keys=ON. Official SQLite pragma/atomic-commit/corruption docs reviewed: EXTRA includes
journal-unlink directory sync; Darwin fullfsync requests F_FULLFSYNC. These are real supported
mechanism/configuration candidates, not dummy flushes, but queried flags/COMMIT/readback do NOT
verify this vendor VFS/syscall/device completion, provisioning-directory durability or stable
media. Result deliberately remains Visible_unacknowledged, never Saved. Actual I/O/full-disk,
cache spill/internal writes, crash/power-loss, folder/restore ordering, valid tampering detection,
production version/identity/upgrade/retention/backup and multi-process races remain unqualified.
Supported Linux SQLite path and a durable acknowledgement need separate bounded qualification;
no runtime/filesystem fork is required by this trial.

Clean strict release rebuild and ./tools/check passed; main list/lock and 64 digests unchanged,
no optional Lean/Lima/Linux/SPT/proof replay. Final native image SHA256
 efade4ad2cdb3869fbfa0c194272be8154994aaec193bf9434027beb487d800d.
Final disk digests/control logs/source/outer-switch export retained privately under scratch/
sqlite_review/evidence; v1 classification failure preserved. All final trial handles/processes
closed; VM remained stopped. No permanent adapter/common multi-backend runner/canonical schema,
full Actual, real recording, UI/voice/network or household adoption claimed.

### Linux SQLite syscall failures and retained-journal lifecycle control

Question/owners/D/P/R recorded in HANDOFF at main 0fc0937 before VM/install/code. Named ignored
scratch/sqlite_linux_review and guest /home/loam/sqlite-linux-review; old SQLite/Irmin/SPT trial
sources and disks not reused/rewritten. Scoped moved HOME/LIMA_HOME successfully starts existing
approved VM without YAML/config edits; no shares/agent/X11/public forwards, userns sandbox/global
restriction retained. Guest Ubuntu 24.04.5/x86_64/kernel 6.8.0-142/ext4. Only missing libsqlite3-dev
installed guest-only at existing libsqlite3-0 version 3.45.1-1ubuntu2.8, no runtime upgrade; strace
6.8 already installed. No global host installation/main dependency adoption or compiler change.

Current 64 own Bakhlo engine/decoder/build bytes copied/checked; new namespaces/fixture marker
used, not historical input rewritten. Backend-neutral publication/values reused; adapter SQL
schema remains a SYNTHETIC control, not canonical storage. Fresh ignored ocaml-system switch
uses existing guest native OCaml 5.3.0 and frozen ac27950 registry: exact same 35 names/versions
as reviewed Darwin trial, native guest/main 50 unchanged. Native binary links system
/lib/x86_64-linux-gnu/libsqlite3.so.0 (3.45.1, vendor source ID ending 57ccalt1), GMP/libc; no
CLI/Presentation/Core/Async/Lwt/Lean. Full earlier logical save/read/history/conflict/replay/
BUSY/refusal/rich/binary/failed-return/SIGKILL/closed-copy baseline passed with Bakhlo marker.
Not a fresh full Linux ordinary suite or production adapter/representation qualification.

DELETE/EXTRA/fullfsync settings: successful trace observes journal fdatasync, creation-directory
fdatasync, journal fdatasync, database fdatasync, journal unlink, deletion-directory fdatasync.
Returned-error injection covers 5 fdatasync EIO + all 34 pwrite64 EIO + all 34 pwrite64 ENOSPC
points of that one update (73 cases). 72 Uncertain: 71 reconcile OLD, 1 NEW after deletion-dir
error; remaining case is visible-unacknowledged NEW despite creation-dir EIO. Entire DB/sidecar
family unchanged by cold read/reconciliation. EIO maps IOERR; ENOSPC maps FULL; finalize/rollback
secondary errors retained, including SQLite already-auto-rolled-back cases (not silently
corruption/zero or proof of non-recording). Injection is syscall RESULT failure, not physical
I/O/full-device exhaustion, short/torn writes, sector reordering or exhaustive timing.

Counterexample preserved: stock SQLite ignores its one-time creation-directory sync error and
COMMIT can succeed. Version-tagged official SQLite 3.45.1 os_unix.c unixSync inspection explicitly
confirms that behavior (directory fsync portability fallback); not a full vendor-patch refinement
or new public issue claim. fullfsync=ON is no Darwin F_FULLFSYNC qualification on Linux.
Successful COMMIT/flags are therefore insufficient for the required all-sync-failures contract.

One separate STANDARD PERSIST mode control, no SQLite patch/custom VFS/filesystem/fork: retained
journal file, checked outer Unix directory fsync after provisioning/before write-open, refuse
missing journal rather than recreate it, synchronous=EXTRA and same immutable-generation SQL.
Assume exclusive namespace owner/prequalified durable parent path; this is NOT adopted policy.
Successful trace has checked directory fsync + five fdatasync calls and no unlink. 76 returned
faults: 1 pre-candidate directory EIO refuses with unchanged family/OLD; 74 Uncertain (71 OLD,
1 NEW, 2 read-only acquisition refusals); 1 visible NEW on redundant SQLite creation-dir EIO,
with required existing namespace independently synced before publication. This supplies a
maintained-path candidate, NOT proof of stable media/complete lifecycle or durable Saved.

Two final journal-header write failures (EIO/ENOSPC) leave hot journals: read-only open returns
structured READONLY/no complete household answer, not stale/empty fallback. Separate copied
families undergo EXPLICIT writable SQLite recovery; both cold-requalify/reconcile OLD, original
fault images unchanged. Trial handle-first shell is not a production admission-before-effects
entrance; valid named controls do not qualify rejected input with pending recovery. Production
must admit before effectful open/activation. Write-open can perform recovery then refuse MISSING_JOURNAL because
SQLite recovery removed it: that error is NOT proof nothing changed. Missing journal alone
refuses writes but valid independently admitted DB read remains available. PERSIST stopped
DB+journal-family restore/history and before/after-COMMIT SIGKILL OLD/NEW passed; no live,
off-device restore or universal diagnosis host. No automatic repair/retry/current-world fallback.

Both clean strict release rebuilds identical; graceful VM stop/start cold restore/history and
isolation passed (not power loss). Source/archive checksums, exact package exports, syscall
traces, all failing/successful families, structured refusal/recovery logs retained privately.
Checked guest-to-host own-source/evidence archive excludes disks/builds/environments/third-party
source. VM stopped, final loopback management listener absent; main Mac ordinary check passed.
No main executable/dependency/schema/semantic change, optional proof/new model/campaign, UI/
voice/network entrance, operational data/cutover, public issue/PR/release/push. Visible remains
unacknowledged; provision/restore ancestor-directory ordering, lifecycle/cleanup contract,
actual device-error/power-loss and maintained production identity/encoding/Saved remain open.

### MirageOS hosted feasibility (one-shot, not production support)

Engine 1b81a2d on Darwin x86_64; official Mirage 4.11.2 source/target APIs inspected,
archive SHA256 `2cbd7924f82d85ad8ed6bab2f8dc95e6bd15a723532193b56af01813ab20b1a7` checked.
Pinned registry ac27950e5eac6c981ad809dff370c937820b7893; independent ignored scratch
root/switch, reused ocaml-system 5.3.0 compiler (not fresh compiler qualification), Dune
3.24.2/Base v0.17.3/Zarith 1.14/intrinsics v0.17.2/sexplib0 v0.17.0. Trial-only Mirage/
mirage-runtime 4.11.2, mirage-unix 5.0.1, Lwt 6.1.2, cmdliner-stdlib 1.0.1 and mirage-sleep
4.1.0 have a concrete outer configure/entry consumer; 51 trial installed selections
(40 initial dry-run installs + two startup dependencies + compiler/base packages), not
51 additions to main. No Core/Async/Irmin/overlay/OS install/main dependency adoption.

60 own lib/application source/build files copied byte-equal. Config main local_libs are
loam_ocaml.domain/application with exact Base/Zarith constraints; configure macosx/no-depext/
no-extra-repo, no argv/reporter/ptime/mtime/random, default_sleep for generated startup.
Built with installed scratch dependencies, NOT monorepo lock/pull/freestanding build;
executed Mirage-generated Unix_os.Main.run, no Presentation/CLI compiled artifacts.
Passed 180-bit addition/inversion, exact corrected source, origin/opening/assertion/presence,
net-zero touch/unknown refusal, retained relation source/remainder 3 and unknown/self/
missing/zero-Effect refusals. Wrong remainder expectation 4 failed at runtime (2, empty
stdout, conditional-remainder witness); restoration passed. Initial no_sleep configuration
failed at generated Mirage_sleep startup-delay reference; default_sleep + proper package
passed without editing generated runtime/engine. Not all device configurations qualified.

Recipe: tools/opam subcommand then explicit --root/--switch; expose main _opam/bin for
reused compiler and trial-bin-before-main PATH plus trial OPAMROOT/OPAMSWITCH for nested
Mirage/Dune commands. Configure in ignored scratch probe,
`dune build --root . dist/loam-mirage-probe`, run native output. Private selection/logs/downloads/generated
metadata/probe remain disposable scratch, not committed adapter or maintained smoke suite.
Host GMP 6.3.0 libgmp.10.dylib/libSystem linkage is NOT Solo5/static-GMP evidence.
Solo5 0.13.0 + ocaml-solo5 1.2.0 Darwin availability dry-run failed (5); metadata accepts
5.3.0 but requires Linux/BSD host. No suitable VM/container/HVT runner on PATH; no Solo5
link/boot, freestanding Base intrinsic/GMP C-stub qualification, full suite in Mirage,
network/storage/recovery/performance/household-use claim. Main 50 selections unchanged,
ordinary/Lean-free checks pass. Next: supported Linux x86_64/Solo5 with explicit static
closure, actual boot, same queries and negative controls; revisit versions/target changes.

Subsequent target preflight read Solo5 v0.13.0 README/docs building/architecture from the
opam-checksummed release (SHA512 cb2f9ea7140d09796dfe2cd5496d9bab858ce1f2144ecaf62cd8f5c9291bcfde8547cd2f42382dea07bd8dcc1ea7173b86ef2ca35247a92a5ed6bfa2ccf056f2).
Linux HVT requires usable KVM access; merely having a VM/container does not establish
nested virtualization. SPT is a freestanding guest under a Linux seccomp process tender,
not hardware-virtualized HVT; upstream labels it experimental and requires libseccomp
>= 2.3.3 on x86_64. It is a possible initial test without KVM, not an endorsed production
substitute or proof of HVT support. First smoke needs no disk/network/TAP setup. Both
require an agreed supported Linux environment; neither was configured/built/booted here.

### Isolated Linux VM and Solo5/SPT preflight

User approved a disposable development VM after confirming no Linux environment.
Observation branch at ff3202c; local Lima 2.2.1 Darwin x86_64 release SHA256
`6b776e4bc41f358e6ee01fefcc78e2eb26f11635a0fcff632234af77a566c6c4` matched published
release asset digest. macOS 15.7.9/Intel i5/16 GiB RAM/native VZ; alternatives UTM/manual
or global brew/QEMU setup were considered, not benchmarked. Keep-observing tool status,
not measured superiority/general CI adoption. Fixed Ubuntu noble release-20260926 image
SHA256 `6a81c37564db9b1ee84e141922625e1d7c5b389b99bb3c572e0243607d5bb4d2`, no fallback;
actual guest Ubuntu 24.04.5 LTS/kernel 6.8.0-142-generic/x86_64. 2 vCPU/4 GiB/24 GiB sparse
virtual disk. Private LIMA_HOME/plain mode, no workspace/home mounts or inherited host
SSH keys/agent/X11, containerd or guest-agent service; guest mountinfo and host-path/agent
absence checked after restart. Managed SSH listened only on 127.0.0.1; outbound package
networking allowed. Not an air gap or a comprehensive malicious-guest/supply-chain audit.

Boot, guest-only signed apt prerequisites (GCC 13.3.0, make 4.3, GMP 6.3.0, libseccomp
2.5.5), seccomp CONFIG_SECCOMP/CONFIG_SECCOMP_FILTER=y verified; no /dev/kvm as expected.
Only selected Solo5 v0.13.0 source archive transferred, SHA512 checked in guest against
opam digest recorded above; configured/built with -j2. Upstream standalone C test_hello.spt
executed via solo5-spt --mem=32, reported bindings v0.13.0/hello/solo5_exit(0); non-ELF
synthetic input refused (1, empty stdout, invalid-executable/ELF-header diagnostic).
Graceful stop/restart and repeated isolation/hello checks passed, stopped at handoff.
Cold image download ~597 MiB; one final allocation ~2.3 GiB guest disk/4.9 GiB trial tree,
not workload/latency guarantees. Prerequisite package versions are mutable distro evidence,
not a hermetic OS lock. No host brew/OS installation/login hooks or main lock changes.

Initial XDG_CACHE_HOME did not redirect Lima's macOS Go cache: the owned image-cache
bucket was moved from ~/Library/Caches/lima into scratch, future commands scope HOME as
well as LIMA_HOME. Restart verified with scoped HOME; only that owned bucket moved.
Empty findmnt output returned success, so absence evidence uses raw mountinfo rather
than that status. Negative-control diagnostic-case and unset-variable harness errors
were corrected and checks repeated; they were not hidden as passing isolation results.
Downloads/keys/VM/config/private logs/build artifacts remain ignored, no upstream source
copied into product. This confirms Linux build-host and C/Solo5-SPT plumbing ONLY:
no Linux ordinary OCaml suite, Mirage/Base/Zarith engine SPT image/static GMP C stubs,
HVT/KVM/network/disk guest, Irmin/storage/crash/recovery or household use qualified.
[Development](DEVELOPMENT.md#approved-isolated-linux-vm-development-trial) owns local
start/stop/teardown recipe; next consumer is actual unchanged engine static link/boot.

### Linux native replay and MirageOS/Solo5-SPT engine (bounded, trial guard required)

At a36c584, user approved actual engine boot before early Irmin persistence evaluation.
133 selected own source/build/test files + synthetic example transferred with SHA256;
no git/environment/operational data. Guest fresh tools/bootstrap compiled OCaml 5.3.0,
installed all 50 lock selections exactly. tools/check: 151 expect tests/unchanged ten
campaigns/100,000 generated cases/three cram suites; forced package tests, @install,
nonexistent-LEAN check and clean native engine-only passed, no outer compiled artifacts.
Bubblewrap was missing; guest-only apt installed it. Ubuntu AppArmor then denied uid-map;
its distro /usr/bin/opam profile does not match local tool. Same userns allowance scoped
to /home/loam/engine-native/.tools/opam, global restriction and opam sandbox remain enabled.
No host OS/config changes; Linux baseline selections stayed unchanged after cross trial.

Separate guest scratch root/43-package switch reuses that fresh compiler via ocaml-system;
Mirage 4.11.2, ocaml-solo5 1.2.0, ocaml-src 5.3.0, Dune 3.24.2, opam-monorepo 0.4.3.
Initial Solo5 0.13.0 did not match generated Mirage bound <0.13.0: selected 0.12.1 and
rebuilt cross compiler, did not bypass constraint. Main manifest/50-entry lock unchanged.
Official dune-universe overlay fixed at 632df22c65362cb34fd792f701d7d2a6518cdb60 (archive
SHA256 41d610eeb7c0bc2ed77c0db989bf20c18627d70e2fe67f19124d914218dfbece) + frozen ac27950
registry. Cross closure 64 entries/25 source pins: Base v0.17.3, ocaml_intrinsics_kernel
v0.17.2, sexplib0 v0.17.0, Lwt 6.1.2, mirage-runtime 4.11.2, mirage-solo5 0.10.0.
Trial Zarith 1.14+dune+mirage1 SHA256 915bd53ebb608729eb76b4e5bc0580090d8428fe919c9bf9a5dcd39f739b49f7:
z.ml/.mli, q.ml/.mli, big_int_Z.ml/.mli and caml_z.c byte-equal to upstream 1.14; configure/Dune
packaging differs, not claimed a general refinement. GMP 6.3.0-1 Dune cross package SHA256
cafe5beff5f35cb4451e341e1c07a019ac7047dd280ff55410e42ccc133bb757; underlying GMP 6.3.0.
Both roots isolated, explicit main compiler PATH/trial opam exec + nested env needed.
Monorepo 0.5.0 AND 0.4.3 stock lock failed current-switch detection here; explicit frozen
repositories and actual guest global-opam-vars (including monorepo marker) resolved.
A marker-absent lock omitted engine deps and was rejected, not boot evidence. Compiler/
core package pins verified before pull/build; no invented defaults/availability bypass.

mirage configure -t spt, no depext/disk/network/argv/reporter/time/random, default_sleep;
monorepo lock/pull, dune release cross build -j2 with original strict-sequence/8/9/11 flags.
60 engine source/build files byte-equal. No engine or generated runtime source edits.
UNMODIFIED vendored Lwt build first pulled in unselected lwt_runtime_events and failed
fstat from OCaml runtime-events consumer. Dune --only-packages cannot mask vendored libs.
Trial-only duniverse/lwt/src/runtime_events/dune adds (enabled_if (<> %{context_name} solo5)):
stock Lwt select uses its existing without-events implementation, no dummy fstat/no
numerical weakening. Clean rebuild confirmed no tracing CMXs/outer libraries. Thus this
is NOT stock dependency-closure support or a maintained/release-ready Mirage adapter;
revisit proper package-selection/upstream fix before permanent adoption. Shell PS1 warning
was scoped away for final clean build, no guest global shell edits.

Actual generated Solo5_os.Main.run loaded by matching solo5-spt --mem=128: 180-bit add/
inverse/signed corrected source, four supports, unknown/net-zero-touch refusals, retained
relation source/partial remainder 3 and missing/self/zero-Effect refusals passed (0).
Wrong expected remainder 4 failed (2, conditional-remainder witness, NO PASS; diagnostics
on guest stdout), restored 3 passed. Restored image matched its pre-control SHA256;
clean build/static inspection and VM stop/restart with same image/isolation passed.
ELF x86_64 EXEC/Solo5 SPT ABI 2/empty devices, no dynamic section/undefined symbols;
GMP code linked in image, no host GMP dylib. PT_INTERP is intentional /nonexistent/solo5/
sentinel, not a Linux dynamic loader (initial no-INTERP check corrected). Image 7,872,208
bytes, SHA256 b1d24be5139f428157139eb443ae1b7d31404d4e00dbf57f2eebe9072ac9c66a; one
restoration hash equality is not universal reproducibility. VM stopped; ignored private
logs/scripts/sources/lock/image retained, nothing third-party/generated committed.
No full test suite IN SPT, HVT/KVM, target choice, devices/I/O, Irmin/storage/crash/recovery,
real data/household use, source-install client qualification or optional proof replay.
Next named consumer: bounded Irmin backend durable record/reopen, with concrete generation/
admission/retry/recovery contracts; no storage format/authority follows from this boot.

### Irmin block persistence (bounded, two trial dependency fixes required)

At fa113a6 user approved continuation toward MirageOS + Irmin, not main dependency/schema/
data adoption. Question/owner and D/P/R/instruments recorded in HANDOFF before prototype;
additional stock retention failure/reachability-control question recorded before patching.
Only selected own/synthetic source; no household data or sibling build/modification/source
copying. Read-only f441f91 sibling status/remaining-cutover route is a historical reference,
not full parity or operational migration evidence. Ordinary engine/parser evidence reused;
no new model/theorem/random campaign for outer plumbing.

Official Irmin 3.11.0 archive SHA256
`09996fbcc2c43e117a9bd8e9028c635e81cccb264d5e02d425ab8b06bbacdbdb`,
Chamelon 0.2.1 `782b84fc81d7bf34fe10442437c6c507ca7ada2c9c822970cc23261be6a5178c`
checked; both declare ISC. Irmin Mirage helper supplies clock-based info, not storage;
examined Git.Mem-oriented wrapper did not establish guest-local persistence (remote push/
sync out of scope). Mem cannot persist; Unix pack/fs does not establish freestanding I/O.
Irmin-fs logs bad value decode and returns None; bad keys may be skipped, unacceptable as
an unqualified LOAM boundary. Trial consumer instead uses Irmin CA/AW makers over Chamelon
KV + Solo5 BLOCK_BASIC, with a small owned backend: strict binary decode/hash verification,
byte-identical append-only collision check, one borrowed FS/mutex, closed handles, serialized
local CAS. Watch/clear explicitly unsupported, not fake success. Batch is NOT a transaction;
no multi-process/multiwriter/crash atomicity claim.

Same approved Ubuntu guest/root/compiler/43-package host switch, no new OS prerequisites.
Frozen registry/official overlay and explicit actual monorepo variables as above. Cross
closure 93 entries/65 package-source pins (59 distinct URLs), not installed-package counts;
core/compiler/runtime/GMP/Zarith pins unchanged. New consumed selections include irmin/
ppx_irmin 3.11.0, chamelon 0.2.1, repr/ppx_repr 0.8.0, digestif 1.3.1, checkseum 0.5.3,
cstruct/ppx_cstruct 6.3.0, mirage-kv 6.1.1, mirage-block 3.0.2/block-solo5 0.8.1,
mirage-ptime 5.2.0, optint 0.3.0, ocamlgraph 2.2.0, JSON/UTF/PPX support, parsexp/sexplib
v0.17.0; no Core/Async. Vendor selection changes ocamlfind 1.9.8 -> 1.9.5+dune and uutf
1.0.4 -> 1.0.3+dune in CROSS lock only, not native switches. Native macOS/Linux lists remain
all 50 main lock entries exactly; main manifest/lock/tools/formal untouched. Dependency
cost is meaningful: no implicit adoption merely because a freestanding build succeeds.

Mirage configure SPT/default argv/sleep/ptime, no reporter/mtime/random/network. Actual
POSIX clock needed for FS write metadata, not household date/commit chronology; supplying
no_ptime failed Ptime_clock unsupported-platform, corrected through SDK, not dummy time.
One exclusively owned 32 MiB synthetic disk, one process/tender at a time, --mem=256;
explicit format with program-block size 16 (upstream tests), NOT the sector size 512.
Initial 512 caused allocation abort even at --mem=512; direct root-write/bounded GC controls
passed, corrected configuration proceeded. Long 128-hex-character hashes exceeded FS's
32-character name bound; shard full hash into 16-character components, never truncate.
Trial main-branch key bound is explicit; not arbitrary branch/path support.

76 own engine/CLI/Presentation source/build files byte-equal; selected CLI archive and final
probe archive checksums verified in guest and extracted file digests matched. Engine and
parser unchanged, no generated-runtime edits. Trial storage is ONE Contents.String fixture
blob at snapshot per immutable commit, including raw source/support/provenance, synthetic
v2 marker only; no canonical format/unknown-section/full Actual claim. Read exact commit
once, then decode/source/query admit from those same bytes, recompute quantities/remainders.
Publisher qualifies before writes, checks expected head, creates immutable objects/parent
then head CAS; stale update refuses without auto-merge/retry/retarget. Missing/unformatted
read refuses, never auto-formats/initializes. Commit info timestamp 0 is explicit synthetic
storage metadata, not Event/date evidence; derived answers not persisted.

**Stock Chamelon FAILED retention.** Initial save/process reopen passed. Update changed
head and new generation reopened, BUT old Contents lookup failed Irmin hash verification;
no successful update marker. Independent KV-only first-file save -> new process -> second
file write -> first-file reread reproduced changed old bytes (2, no retention PASS).
Fs_internal.Traverse.get_ctz_pointers stopped at index 1, while File.last_block_index starts
at 0; two-sector values left first data block out of reachability/free-space accounting.
Trial-only change `| Ok l, 1 -> ...` to `| Ok l, 0 -> ...` then passed SAME independent
control and new-disk Irmin old/current retention. This strongly isolates the bounded issue,
not a general filesystem correctness proof. Unmodified 0.2.1 is disqualified for this
workload; do not call the guarded result stock/production storage support. Prior Lwt
runtime-events Solo5 Dune guard also retained. Neither third-party patch is committed or
adopted; maintained resolution/alternatives/patch ownership must precede promotion.

Guarded controls passed: 180-bit signed corrected arithmetic, all four support families,
net-zero touch/unsupported versus supported zero, retained original relation source and
remainder 3 -> 2, unknown relation not zero; exact bytes/history/parent retained. Separate
process save/read/update and cold old/current history after graceful VM stop/restart passed
with same disk/image SHA256. Unsupported fixture syntax, invalid over-discharge, stale
expected-head/CAS and unsupported watch refused; before/after whole-disk hashes identical.
Deliberately malformed head on separate synthetic disk refused 2/invalid hash-size witness,
NO read PASS, unchanged corrupt disk; no decode-to-None. A failure after publication may
have changed head (stock counterexample did); abort/no success, not blind retry or rollback.
This does not implement a production uncertain-result/recovery protocol.

Clean release cross rebuild with original strict-sequence/fatal 8/9/11 flags passed;
no tracing CMXs, ELF x86_64 EXEC/Solo5 SPT ABI 2, one store BLOCK_BASIC manifest/no NET,
no dynamic section/undefined symbols; expected nonexistent Solo5 INTERP sentinel. Image
12,671,416 bytes SHA256 `8c7705573a1c6381eb944ef9f36e13024824b8e6d84bffef957658bf1b95f76d`;
lock `ee466c3cca82215cb795a437af37523242addd60161d500297dd7f0037dd413f`.
Clean rebuild matched image hash and boot/history controls; not universal reproducibility.
Nonfatal /etc/bash.bashrc PS1 diagnostics remain in this clean build log; scoped ENV/PS1
attempts did not remove all, no global shell change. Original engine-probe image unchanged.
macOS ordinary suite passes; no full suite IN SPT/source-install/other-platform/proof replay.
VM STOPPED, logs/archives/locks/disk/source/build private ignored scratch, no listener.
No abrupt process kill/power-loss, device flush/barrier, torn-write/disk-full/I/O-error,
backup/restore/migration, large/many-block reliability, useful input UI or household authority
qualified. Revisit those failure models, backend/format/runtime/device/clock/scale before
adoption; success here establishes only a guarded bounded storage/reopen path.

### Storage route preflight (source/metadata only; UI deferred)

User prioritized storage/reliability and deferred Bonsai. Question/D/P/R recorded before
inspection; no VM boot/build/dependency adoption. Official GitHub/read-only source checks:
Chamelon latest release remains v0.2.1; non-archived main 3cb012b65c63df9b5d84ba995c04fcf625b4cf09
(2025-10-09) still stops CTZ traversal at index 1. That main commit fixes directory size,
not our independent first-data-block counterexample. Maintenance timestamps/non-archive
status are observations, not support guarantees. Issue #21 reports different model-found
bugs; maintainer says those were fixed before v0.2.1, so open issue label is NOT evidence
that the reported bugs remain or that our issue is already reported. No issue/PR filed.

Bounded alternative check, not an exhaustive search: Wodan main
fd70abdb45fa176557178435217e0ab114e4e4d0 (2021-09-16) has Irmin backend, but published
README targets Mirage 3/OCaml 4.08–4.11 and hardening remains open; manifests pin forked
block APIs/nocrypto, lru 0.3.0, Unix packages in Irmin binding. Not in frozen registry;
port/closure/key-size/value-size/flush cost is substantial, not a drop-in maintained choice.
Frozen fat-filesystem 0.15.1 requires Mirage_kv >=4 <5 and Unix block dependency, versus
trial KV 6.1.1; no compatibility/retention claim. git-kv 0.2.3 is Git-oriented with network/
sync closure, not demonstrated local block storage; SNKV metadata describes SQLite-engine
FFI, not freestanding I/O. These observations do not rule out every alternative or choose
one. Do not implement a new filesystem just to avoid an explicit dependency decision.

Matching Solo5 v0.12.1 source raises an INDEPENDENT durability gap: common block_attach
opens O_RDWR (no O_SYNC/O_DSYNC); SPT block write calls pwrite64 and returns on full length.
Public ABI has read/write/acquire, no flush; SPT block seccomp setup admits pread64/pwrite64,
not an added fsync/fdatasync boundary. Hence current file-backed clean restart evidence is
NOT durable acknowledgement after host crash/power loss, regardless of the CTZ fix.
First guessed tender-source path returned 404, corrected to spt_module_block.c; no empty
file used as source evidence. Sources read at explicit tag/HEAD where cited, no patch/build.
Next define saved/rejected/conflict/uncertain outcomes and required persistence ordering/
barriers, then qualify a maintained target/backend/fix route with retention + fault/restore
controls. No dummy sync, compiler downgrade, semantic weakening or adoption follows.

### Guarded block retention, interrupted publication and offline restore controls

After 683dbd5 user reaffirmed MirageOS + Irmin/new-value exploration WITH maintainability,
then approved continuation, not SQLite pivot/new FS/main dependency/fork/public reporting.
Question/D/P/R/failure bounds recorded before scratch code; same approved guest, 93-entry
cross lock, compiler/core/engine unchanged. 76 own source/build digests matched, original
Irmin image unchanged. No new OS prerequisites or package install. CTZ/Lwt trial guards
still REQUIRED, unmodified tender; no new sync primitive or stable-media claim.

New separate guest /home/loam/storage-controls and fresh 32 MiB synthetic disks; original
success/counterexample disks never formatted. Direct KV byte oracle, 16 sizes 0/1/127/254/
255/256/257/507/508/509/1023/4095/4096/8192/32768/65536: first generation checked after
writes, next process append of another generation rechecks ALL old/new bytes, cold process
and graceful VM restart reread passed. Only bounded shapes/allocator history, not general
FS correctness, arbitrary size, overwrite/delete/disk-full or torn sectors.

Same synthetic Irmin seed/update source and parent: 180-bit/four-support/unknown/provenance/
remainder 3 -> 2 checks reused. Update made 95 Mirage_block.write API calls. Every before/
after call point injected a failed promise without FS close: all 190 refused with no
publication PASS, next-process actual head decoded/hash-checked as supplied old OR new,
retained old commit/blob always exact. 186 OLD / 4 NEW: failed call can follow publication,
so "failure means not recorded" is falsified. Driver may split ONE API call into multiple
512-byte writes; this does NOT cover interruption inside a call/partial-sector I/O or all
ordering/interleavings. No fallback/merge/repair. Recovery disk digests remained unchanged.
Four actual tender SIGKILL controls paused before/after selected API calls (1,94,95):
2 OLD / 2 NEW, no publication success, same next-process checks/read-only digests passed.
These are process-failure evidence under a live guest OS/cache, NOT host/VM power loss.

Tender-stopped complete disk copied to separate file, exact bytes/digest and old/current
history verified, then repeated after graceful VM restart with same disk/image hashes.
This is offline same-guest copy/restore, not live-consistent/off-device backup or hardware
failure recovery. Clean strict release rebuild matched final image SHA256
0eb115af5b7ed237252f76d0d689a538d36b436e2d2ec92033f7f15cfd1122ce; SPT ABI2/static/no undefined
symbols/no tracing CMXs, one BLOCK_BASIC/no NET, prior lock SHA256 unchanged. Original
8c770557 image unchanged. Archive transfers/checksums, macOS tools/check and isolation passed;
VM STOPPED. PS1/cross-configure diagnostics and macOS archive provenance-xattr warnings
retained. First shell harness mutated caller label, causing missing digest filename; corrected
using positional args/new disk/evidence names. Initial elftool PATH and driver source-path
checks corrected before inspection; failures are NOT storage counterexamples.

Official Solo5 issue #330 remains open and discusses ordering/durable barriers, including
2025-10 discussion; no supported flush earned from issue text or maintainer promise, no
public issue/PR filed. Source/clock/device/package provenance assumptions remain. Maintained
CTZ/Lwt selection AND actual durability boundary/ownership remain prerequisites; current
contracts separate visible/reconciled state from Saved. No household authority/production
API, idempotency/retry protocol, power loss, real I/O error/torn-write/full-disk campaign,
backup policy/migration, full suite IN SPT or full Linux native/proof replay newly qualified.
Ignored source/logs/images/disks retained; no permanent dependency/third-party source commit.

### Client toolkit preflight (metadata only, not a UI qualification)

After 28541ba user requested laptop/phone/AI-chat recording and viewing, desktop Notty
preferred, optional Bonsai browser trial. Named consumer/question/instruments recorded in
HANDOFF before review; no installs/build/browser/network test or main lock changes.
Frozen ac27950 registry: notty 0.2.3 (ISC) permits OCaml >=4.08 <5.4, Dune >=1.7,
cppo/uutf, optional Lwt; direct gates fit current OCaml 5.3.0/Dune 3.24.2, not solved-closure
or terminal/platform evidence. bonsai v0.17.0 (MIT) requires OCaml >=5.1, Base/Jane Street
v0.17 and substantial Core/Async/ppx_jane/Incr_dom/Virtual_dom/RPC/web dependencies.
Dune >=3.11 <3.24 excludes main 3.24.2; js_of_ocaml >=5.1.1 <5.7 admits compiler versions
5.1.1/5.2.0/5.3.0/5.4.0/5.5.2/5.6.0 in this registry, ALL exclude OCaml 5.3 (latest two
allow <5.2). Thus stock Bonsai v0.17 cannot simply be installed into the qualified main
switch. Revisit a separately reviewed browser-only toolchain or compatible maintained
release/alternative, not silent backend downgrade/constraint bypass/Number-based quantities.
js_of_ocaml 5.6.0 binds compiler = version and declares GPL-2.0-or-later / LGPL-2.1-or-later
WITH OCaml-LGPL-linking-exception; distribution/component obligations need separate review.
Full transitive closure, browser behavior/mobile ergonomics and any independent frontend
compiler remain unqualified. UI deps must stay outer; no Jane Street endorsement inferred.

[Optional specification](../formal/README.md) states nine row-selection, signed-delta and
whole-premise lookup laws. It does not prove graph admission, group indexes, Actual/support
truth, OCaml/Base/Zarith refinement, loading or durability. Recheck artifact/assumption/
correspondence changes, not every unrelated consumer edit.

A prior one-shot native synthetic probe at `1d3de2f` measured source/image/query CPU costs
for 1,000/10 and 10,000/100 Events/groups, singleton roots, empty cuts and 10,000 alternating
queries. The larger image took about 1s on this host; parsing/I/O excluded. This is not a
maintained benchmark, target or current latency guarantee. Group construction repeats
source walks; revisit with named workloads/limits before optimizing or choosing a cache.

Storage/publication, other Linux/Apple Silicon targets, full evidence families, household
authority and large-history operational reliability remain open. Do not relabel absences as coverage.
