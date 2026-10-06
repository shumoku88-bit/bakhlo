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

## Current product direction — small household questions, AI optional

User delegates bounded development toward an ordinary, friendly household question machine,
NOT a household-specialist LLM/SLM. Deterministic operations answer small explicit questions;
Presentation explains uncertainty/next checks without inventing missing facts. AI is an optional
untrusted entrance, never a runtime/model dependency or authority. Keep owner-readable complete
evidence/export separate from least-disclosure client answers; projections themselves remain
sensitive. Current Unix progress continues; shellless/restricted Mirage composition is a future
hypothesis to qualify, not automatic confidentiality or a reason to rewrite Core.
Daily-use recording/save/reopen/correction remains the later product path. Delegation is not
permission for dependencies, new UI/store adoption, private-data writes, recovery/migration,
operational cutover, sibling build/source copy, publication or push.

## Completed bounded task — bilingual four-currency draft UI

User approves extending BOTH trial UIs with Japanese/English and JPY/EUR/USD/ILS selection
and exact decimal entry. Visual feedback: Bonsai feels slightly richer (color/style), NOT a
permanent framework choice. D: clean d865bfa, main 50/lock, two native ignored UIs; P: whole
proposal/correction/support gates, exact stock/Ox bytes and PTY controls above. R: localized
labels/errors without changing identity/memos; explicit decimal scale, no float/rounding,
no mixed-currency quantities or reinterpretation on selection/correction. Owners: a SMALL
trial money adapter defines explicit versioned quanta and exact text conversion; bilingual
labels render typed UI states; existing workbench/engine own proposals/answers. Fresh SYNTHETIC
seed with ASCII stable loci and separate explicit four-currency support; do not reinterpret
old jpy data. Trial policy announced: JPY 1 yen/quantum; EUR/USD/ILS 0.01/quantum. Named trial
Measure IDs encode this policy/version; not production currency/catalog/storage adoption.
Dot-decimal input in BOTH languages, no comma/grouping/symbol/exponent/coercion/rounding.
Language switch preserves document/draft/memo; currency switch refuses nonempty amount or
correction (start a new empty draft); direct workbench correction also binds currency/owner.
Reuse SAME two native frontends, isolated installed dependencies/compiler roots and existing
smoke/PTYs; targeted checks: 4 currencies x2 languages, cents/180-bit exactness, refusal,
separation, correction/history and byte equality, terminal resume. Preserve first paired
source/images/controls before editing. No new framework/package/model/benchmark, private
read, canonical writer/Saved/FX/valuation/RTL/locale service, main dependency/compiler change
or push. Currency scale is explicit TRIAL scope, not a reinterpretation of existing evidence.
Revisit before FX/region-specific formatting/real data/persistence/permanent UI adoption.
Completed: ignored `money.ml/.mli`, `locale.ml/.mli` consumed by BOTH native renderers and
shared editing/engine workbench. 4x2 smoke checks + exact stock/Ox complete proposal/answers
pass; real PTYs exercise EUR 12.34 -> correction 15.01, USD 0.01, ILS/JPY precision refusal,
locked correction currency, live language/error switch and canonical terminal resume. Final
wallets JPY 998 / EUR 84.99 / USD 199.99 / ILS 298.77, identical source checksum. Original
paired v1 sources/images/hashes retained; main 175/four cram, format, exact 50/lock unchanged.
[Verification](VERIFICATION.md#bilingual-four-currency-draft-ui) owns new evidence/bounds.
Try `./scratch/tui_comparison_review/try-ui bonsai en` (or `notty ja`): Ctrl-L language,
Ctrl-K currency from empty new draft, Ctrl-N new, Ctrl-E/Ctrl-U correct, Enter validate,
Ctrl-Q quit. Candidate work still disappears at exit. Human IME/keyboard feel remains next.

## Active bounded task — paired Notty / Bonsai_term TUI trial

User explicitly requests building with BOTH candidates and comparing while using them;
this authorizes a bounded synthetic UI trial, NOT main dependency/compiler/store adoption.
Question: can the same tiny expense-form/list/correction interaction be pleasant and maintainable
with direct Notty versus Bonsai_term on the current Mac? D: clean 0438384, main OCaml 5.3.0/
50 locked packages, Darwin x86_64, pure admitted documents/proposals/projected answers available;
public Bonsai_term default `oxcaml` 2457232d3aa144fb887a053748a920544db60f72 uses Core/Async/
Bonsai/notty_async/notty-community and its README requires OxCaml. P: 175 expect/four cram,
byte-bound proposal/currentness controls; no existing production TUI/writer. R: native host/
compiler/package compatibility, Japanese editing/display widths, focus/resize/list selection,
UI effort and preserving typed refusals without GUI-side ledger arithmetic.
First instrument: pinned public README/opam/host review and ISOLATED dependency solve, then a
minimal native synthetic consumer ONLY for candidates whose prerequisites are qualified.
Main switch/lock/Core meanings stay untouched; approved trial dependencies stay in ignored
scratch/root/switch with no global install, OS change, VM, protocol framework or sibling build.
Do not install an alternative compiler or substitute a browser mock when native prerequisites
are blocked: report the concrete blocker and ask for the applicable next decision. No pasted
private data, operational files, permanent UI choice, canonical format/store/writer, recovery,
Saved or push. A paired visible consumer must use equivalent scenarios/engine gates; an unrun
candidate never receives a performance/usability verdict. Revisit before expanding host/toolchain
or UI/storage scope. Record actual runnable vs preflight-only results separately.
Preflight: default ac27950e5eac6c981ad809dff370c937820b7893 and Ox registry
f1bd228dda31430bf6271f0f9adb2e604c6957ca captured. Notty-community 0.2.4 needs seven
additional packages in an isolated system-5.3.0 alias switch. Bonsai_term pinned preview
v0.18~preview.130.106+341 solves with OxCaml 5.2.0minus40 (NOT Ox 5.4) and 254 packages,
including empty guards, after a 60s solver timeout and bounded precise-request retry.
Mac x86_64/configure and existing clang/make/autoconf/pkg-config prerequisites reviewed;
no OS install. User was notified of the seven/254 difference and then requested continuing.
Proceed with the dedicated Ox UI trial build, not a main compiler/lock change. Same CURRENT
pure engine source may be compiled ONLY in the isolated synthetic UI consumer; this alternate
compiler/Base is NOT the earned main backend or authority. Compare exact proposal bytes/answers
with stock-5.3 workbench controls before any usability judgment. UI-only dependencies stay outer.
First paired increment: BOTH native binaries now build/run in ignored
`scratch/tui_comparison_review`, with a shared pure engine workbench and tiny interaction
contract but separate Notty I/Unix and Bonsai View/state-machine/Async frontends. Whole
admitted candidate/source access stays owner-side, no new balances or Store. Same stock/Ox
controlled proposal/answers compare byte-identically; both smoke checks cover 1000 -> 990
-> correction 985, retained original Event/text/edge, exact 180-bit answers, input/stale-row
refusals, unknown/presence, scalar/paste and clipping geometry. Real script PTYs pass UTF-8
input/focus/add/correct/quit, same final checksum and child exit 0. Full terminal state matches
after canonical input resumes; failed immediate snapshot probes retained: ONLY Darwin PENDIN
transient state, not missing user flags. Details/bounds in
[verification](VERIFICATION.md#paired-notty--bonsai_term-synthetic-draft-ui-trial).
Actual installs: Notty 16 total (nine baseline aliases + seven additions), Bonsai 249 including
guards (preflight 254); ~8.7GiB ignored trial tree, ~4.6/53MiB binaries. This is setup/artifact
evidence, not UI latency/RSS/usability. Main compiler/exact 50/lock/dependency directions unchanged.
No VM/OS/global installs, operational data, canonical storage/UI/runtime adoption or push.
Try BOTH before deciding: repository root, >=64x25 interactive terminal, SYNTHETIC inputs only:
`./scratch/tui_comparison_review/try-ui notty`, then `.../try-ui bonsai`.
Enter 10/Tab/memo/Enter; Ctrl-E/Ctrl-U/15/Enter; Ctrl-N new, Tab/Shift-Tab focus, arrows list,
Ctrl-Q quit. Fixed visible synthetic date, not a clock; no currency display-scale decision.
Candidates disappear at exit. Bonsai ALSO needs app-owned focus; no turnkey form or incremental
performance verdict. Human macOS IME/grapheme/cursor editing, live resize/long-list feel and rich
components remain unqualified. Next: user compares actual interactions; keep permanent choice
open and do not recast this as practical saved recording.

## Completed bounded task — reuse whole-admitted documents without stale publication

Question: can the measured 100k append/correction path avoid rebuilding the SAME complete
immutable evidence while still freshly checking actual selected bytes/history under the lease?
D: clean 8ea1cc9/main 50; pure proposals retain byte/image pairs, Unix trial repeats whole
admission before/under lease and cost data isolates this work. P: 173 expect/four cram plus
v3 receipt/conflict/refusal/interruption and 10k/100k exact-byte/cut/quantity controls.
R: unforgeable bytes/image binding, reuse vs authorization, same-token changed bytes/metadata/
missing ancestor between preview and gate, and actual CPU/RSS improvement. Owners: `text/Read`
seals complete admitted bytes+existing image; `Propose` consumes an admitted base and seals
whole-admitted new bytes. A versioned ignored Unix trial freshly captures ALL envelope bytes;
only exact same namespace/generation/envelope or identical sealed document bytes may reuse
admission INSIDE one call. No persistent/global/mtime/digest-only cache, partial admission,
per-group optimization, new store/layout/retention policy or filesystem. Replays/cuts/old source
and uncertain outcomes stay unchanged; admission is never authority to publish.
Exploratory acceptance: compare unchanged 10k/100k flat/path three-generation consumer;
100k complete append/correction <=5s and peak RSS <=512MiB are REVIEW hypotheses, not user SLOs.
Old broad budgets passed; user now explicitly requests a measured-seam experiment, not automatic
maintenance. Select focused existing native expect/type clients plus REUSED trial/cost controls,
including deliberate inter-check mutation/namespace/parent refusal, process kills and checksum.
No new model/campaign/framework/package/VM/Lean/operational data; v3/cost baseline sources/images
and input stores remain intact in ignored scratch. Publication sync/error/recovery/Saved remain
unqualified separately. Revisit or stop on a lost gate/provenance or no measured improvement;
no main canonical adapter/cutover, UI or push. Ask user before any needed real-data read.
Completed: sealed `Read.document` + consumed typed-base proposals, whole new-candidate gates;
raw entrances retain refusal precedence. Main 175 expect/four cram/type boundaries; versioned
ignored `scratch/text_publication_reuse` passes all existing native lifecycle controls plus ten
pre-lease byte/metadata/history/concurrent-head interleavings and pre-write returned error.
Negative ID-only-capture binary fails; qualified binary passes. Paired current-engine 100k
workers: append flat 6.69-6.70 -> 2.42-2.45s/path 7.91-7.99 -> 2.83-2.86s; correction flat
9.96-10.10 -> 4.54-4.75s/path 11.86-12.00 -> 5.44-5.54s. Reuse peak append ~410/430MiB,
correction ~562/585MiB. Stronger 5s/512MiB hypotheses PARTLY unmet; do not relabel them or
continue speculative optimization. Whole reconstruction/reopen/copies/group costs remain;
complete retained baseline/reuse store trees are byte-identical. Fresh raw envelopes are
checked twice; only exact qualified immutable bytes reuse admission, never currentness.
[Verification](VERIFICATION.md#whole-admitted-document-reuse-and-fresh-publication-gates)
owns paired-engine/baseline memory caveat, controls, retained evidence and no Saved/security
claim. Pure seam retained, physical reuse stays trial-only; main 50/lock and original v3/cost
artifacts preserved. No actual syscall/recovery/lifetime qualification, real data or push.

## Completed bounded task — synthetic scale/copy/reopen cost review

Question: does the existing native text proposal/Unix trial stay plausibly interactive at
10k/100k retained ordinary Events, and what actually grows with cuts and full snapshots?
D: clean 260950b/main 50, unchanged pure reader/proposal and ignored Unix trial available.
P: 173 expect/four cram, source/cut/unknown gates and v3 selection/replay/interruption controls;
prior 1d3de2f 10k/100 empty-cut group CPU observation (~1s, no parsing/I/O), not a target.
R: acquisition vs decode/source/support/query costs, whole-proposal/publication/reopen peak RSS,
three-generation bytes and 100-extra-group sensitivity. Native owned cost consumer alongside
existing ignored trial; link CURRENT engine + existing Store, do not port a historical harness.
Workloads: 10k/100k two-Effect Events, singleton roots versus disjoint four-Event correction
paths, half-root wallet cut, explicit food/quiet origins, USD opening, presence/net-zero unknown;
separate 100-empty-cut-group stress. Complete original bytes/history and exact answers must
survive; no partial-source success/cache/index or shortened admission for timing.
Exploratory REVIEW budgets (not user SLOs/adoption): 10k read <=2s, 100k read <=10s,
100k proposal+publish <=30s, worker peak RSS <=1GiB; three generations should retain ~3 complete
images, not pretend linear lifetime history. Resource guard: 120s per process; stop/reassess
on failure or >2GiB observed RSS rather than blindly expanding the workload. No promised latency.
Instruments: staged native CPU/wall timers + existing /usr/bin/time peak RSS, fresh processes,
three single-cut repetitions/ranges, exact quantity/cut/provenance/byte checks and existing
ordinary regression gate. Filesystem caches uncontrolled (not cold-media latency); no new
model/random campaign/framework/package/VM/Lean/real-data access. Maintenance table: measure
reconstruction/group walks before deciding any optimization; other consolidation triggers absent.
Revisit only an actually exceeded budget/measured seam; durable Saved/layout/authority decisions
remain separate. If operational input is later necessary, explain purpose/scope to user first.
Completed: 10k/100k flat/four-Event-path inputs, three fresh-process selection/correction/reopen
repetitions; original bytes/three generations/parent links/old text/edge, four support distinctions
and signed 180-bit quantities survive. Observable 1,000-answer checksum/counts rerun avoids discard-only
benchmark evidence. All exploratory budgets met; no memory/time guard fired. At 100k, source
read ~1.0-1.2s, three-generation reopen ~3.6-4.3s, append ~6.4-7.7s/correct ~9.5-11.4s; peak
worker RSS ~765MiB, 100 extra empty-cut groups ~773MiB/8.5s. These are NOT product SLOs or
cold-media/durable Saved evidence. Full three-generation bytes ~37-42MB; lifetime growth is not
qualified. [Verification](VERIFICATION.md#synthetic-text-scale-and-history-cost) owns ranges,
phase attribution, host/cache/check overhead and unchanged source/lock/50-package controls.
Decision: no main optimization/adoption now; query lookup is already cheap, repeated whole
admission and per-group walks/snapshots are the measured seams. Next: fix a concrete recording
latency/retention requirement and review those seams with independent cuts/provenance/current-
evidence/receipts intact, separately from actual sync/recovery qualification. No real data needed.

## Completed bounded task — synthetic record/select/reopen/correction consumer

Question: can one explicit ordinary Movement proposal retain the admitted base evidence,
be selected in a fresh synthetic Unix text trial, reopen and correct without lost history,
stale-base publication, invented support or a false Saved receipt?
D: clean 2331eeb/main 50; text reader/projection exist; no main writer/encoder/store.
P: 170 expect/four cram, whole source/support and correction/cut gates, retained SQLite/Irmin
receipt/replay/interruption evidence and directory-sync counterexamples.
R: faithful NEW-row encoding/base-byte preservation, admission before effects, selected-vs-
prepared receipt distinction, expected generation/base binding, partial publication and reopen.
Owners: pure `text/Propose` supplies explicit ID/date/effects/optional description and an opaque
whole-admitted candidate; an ignored native Unix consumer owns file/lease/sync/publication.
Reuse the existing read grammar/Movement/source gates, not a whole-world codec or business bus.
Trial-only layout: immutable human-readable complete generations, parent/request association,
explicit provision and one selected head. Atomic selection is not household correction or Saved.
Instruments: a few native expect/type connections, then one named native trial consumer with
fresh synthetic stores, cold process read/replay/refusal and targeted publication checkpoints/
SIGKILL controls. No Python/generated payload, parallel framework/model/random campaign, new
package, VM/Lean/sibling build or operational data. Historical SQLite source has old Loam
namespaces; consult its contracts only, do not rebuild/copy the stale engine/switch.
Assumptions: cooperative exclusive namespace ownership, retained immutable generations and
existing parent path; qualify actual returned sync/cleanup failures, never infer power-loss
Saved from fsync/rename/reopen. Revisit before physical layout/format/store adoption, permission,
concurrency expansion, recovery/cleanup/backup or a durable acknowledgement. Main dependency/
UI/canonical-storage adoption remains absent; record bytes and trial layout stay experimental.
Pure proposal step completed: `text/Propose` add/correct, byte-retaining opaque candidates,
three focused expect connections and public type boundaries. Main macOS check (173 expect/
four cram), forced package tests, release @install, pinned formatting and whitespace pass;
main installed set remains 50. Ignored `scratch/text_publication_review` now consumes it using
CURRENT + complete immutable generation/parent/request files and a cooperative process lease.
Final native v3 controls pass: 1000 -> 990 -> reopen -> correction 985, retained original bytes/
cut/edge/text, exact 180-bit cold read, scoped base/conflict/BUSY/replay/refusal, eight Uncertain
checkpoints (6 OLD/2 NEW), two real SIGKILL OLD/NEW and closed-family cold restore. Prepared
files are not receipts; incomplete temps refuse explicit retry without auto-cleanup. All selected
ancestors qualify before answers/write activation; no malformed/dangling/older-world fallback.
Main/source lock and exact 50-package set unchanged; no old trial switch/VM/Lean/private reads.
[Verification](VERIFICATION.md#unix-text-publication-consumer-synthetic-no-saved) owns precise
controls and limitations. This earns ONLY a native synthetic loop, not main persistence/Saved,
power-loss or actual syscall-fault/lifecycle/security qualification. Layout/ID/path budget stay
trial-only. The bounded scale/copy/reopen review is now completed above; its measurements do
not adopt this layout or qualify lifetime retention, actual failure completion or durable Saved.

## Completed bounded task — friendly quantity answers without raw provenance

Question: can the existing admitted quantity outcome answer “how much at this coordinate?”
without giving its recipient source/cuts/history, while retaining honest exact/presence/unknown?
D: clean 7ffa3f2/main 50; two pure readers and consumed one-image CLI already exist.
P: 166 expect/four cram, earned support/cut/lineage/original-Effect gates, owner explanation.
R: sealed projection correspondence, misleading unknown advice, success AND failure disclosure,
and view-choice refusal before acquisition. Owners: Application copies only coordinate/quantity/
premise FAMILY into a concrete quantity answer; Presentation renders it in Japanese; existing
CLI consumes `--summary` instead of new UI/transport/operation bus. Owner `--explain` remains
separate and full evidence stays internally retained. Summary input failures retain exit class
but withhold raw diagnostics; detail mode remains available to the local owner.
Instruments: a few focused existing expect connections, existing cram/public type clients and
ordinary native/package/install checks. No new model/campaign/harness/Python/theorem/dependency.
Maintenance table: no source initializer/parser/ID/index/performance consolidation trigger.
Bound: supplied synthetic files, whole admission, existing quantity scope only. No model/NL
parser, date/spending/report/Scheduled/recording API, auth/grant service, sandbox/confidentiality
proof, coherent original capture or store/recovery/Mirage replay. A narrow result signature is
NOT access control: future hosts must authorize coordinates/operations and hide acquisition
failures separately; do not hand them an image/file handle. Revisit when a concrete external
recipient or next record/save consumer fixes capability/acquisition/publication requirements.
Completed: distinct projected quantity payloads and Japanese `--summary` are consumed by both
existing read-only CLI entrances. Exact/support-family/presence/unknown survive; no raw provenance
or input diagnostics in summary; full owner evidence/detail remains. Four focused expect plus
existing type/cram connections pass; ordinary/forced package tests (170 expect/four cram), release
@install and optional formatting pass on macOS. [Verification](VERIFICATION.md#friendly-projected-quantity-answers)
owns controls/limits; [Architecture](ARCHITECTURE.md#small-quantity-answer--disclosure-seam) owns
scope. No auth/capability-service/security deployment or live original read is qualified.
The first bounded SYNTHETIC record/select/reopen/correction consumer is now completed above;
its retained publication/lifecycle limits still block main store/format adoption and durable Saved.
Keep the simple question surface; do not grow an unused operation catalog or add an AI model.

## Current work style — native OCaml, no anticipatory harnesses

User requests removing the recent Python/test scaffolding and using native OCaml until
another tool/check is concretely necessary. Cleanup owner: only recent ignored read-review
code/generated executables, not originals or existing Core tests. D: no tracked Python;
P: earned native gates and historical comparison results; R: distinguish disposable code
from retained private bytes/results. Completed scoped code/build-artifact deletion; private
inputs/results preserved, existing native code/tests/lock unchanged. No new test/probe/runtime
or test-suite replay in that cleanup. Subsequent needed read work below is native OCaml,
not a port of the retired harness.

## Completed quantity explanation / one-image questions

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
Stage 2 completed from clean d2b59f4: both explicit-file CLI readers accept optional `--explain`
and nonempty ordered/duplicate coordinate pairs; one acquisition and one whole admission precede
all questions. Shared CLI pair/exit mechanics do not merge reader profiles or support meanings.
Three focused expect connections and existing cram cover late argument refusal, mixed 0/4/3,
whole-read refusal/no partial stdout, Measure/duplicate rows and byte-equal synthetic inputs.
Ordinary/forced package tests (166 expect/four cram), release @install and optional formatting pass;
main installed 50/lock unchanged. [CLI verification](VERIFICATION.md#one-image-quantity-cli-questions)
owns limits. Next: name a human quantity/evidence question and acquisition owner before separately
qualifying native coherent capture. No live-original read or writer follows from these results.

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
The scoped native STRUCTURED reader, owner explanation and friendly projected quantity answer
are implemented for supplied synthetic images; pure Movement proposals and the ignored Unix
record/select/reopen/correction trial are completed above. Any LIVE read still needs a named
human question/acquisition owner and stable/coherent native acquisition before calling an
original read current. No Python/probe port, automatic
root/fallback/recovery or permanent omnibus compatibility/Core ontology by habit. Add checks
only for a concrete unresolved risk; preserve typed missing/unsupported/refusal. User owns
operational cleanup and changed data needs fresh capture. Retained publication/cost work below
follows those useful native boundaries, not immediate main writer/store adoption.

1. Preserve the earned text/SQLite/Irmin selection/reopen/receipt comparison. Before a durable
   acknowledgement, qualify ACTUAL returned syscall/sync/cleanup failures, parent/namespace
   lifecycle, explicit recovery and information-preserving restore under a declared host/device
   model. Native process checkpoints/SIGKILL/fsync/rename/Git commit do not qualify Saved.
   No older-world fallback, implicit repair or new filesystem by default; trial layout is not
   an adopted canonical format/store or a concurrency/authentication service.
2. The user-approved reconstruction reuse above cuts synthetic append/correction time but
   stronger 5s/512MiB review hypotheses remain partly unmet. Set a concrete daily recording
   latency/group workload/retention/host requirement before another optimization. Query lookup
   is already cheap; fresh-process retained-history admission, independent-group walks and
   full retained snapshots still dominate. Do not weaken fresh physical/generation/base checks
   or whole admission, adopt a cache/layout, lower failed bounds or grow the campaign by habit.
   Lifetime history, larger/more-group shapes and other hosts remain unqualified; use one
   bounded native consumer, not a maintained benchmark or operational fixtures, when named.
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
