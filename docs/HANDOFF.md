# Handoff

## Current direction — data sovereignty, canonical S-expression text, MirageOS goal

After 07cd41f, user approved reordering the roadmap: preserve human-readable canonical
evidence and data/meaning/runtime sovereignty, keep MirageOS an explicit future product goal.
[Architecture](ARCHITECTURE.md#properties-to-preserve) owns the requirements; meaning, logical
representation, physical publication and runtime remain separate choices. SQLite canonical
adapter/package adoption is PAUSED; optional rebuildable indexes require a concrete consumer.
User confirms S-expression syntax for versioned canonical evidence after the plain-text and
[minimal syntax comparison](../examples/syntax-bakeoff/README.md). Syntax selection is settled;
exact whole-household schema and physical store remain unadopted. User explicitly approves
Parsexp v0.17.0 in the main outer codec and a bounded ordinary S-expression read/write step.
The existing [isolated codec trial](../experiments/sexp-codec-trial/README.md) remains an experiment,
not a production codec. Syntax selection itself authorizes no dependency or migration.
User now approves the readable/extensible schema and safe-interchange direction below.
User reprioritizes the ordinary daily-use loop before hledger export/import; these adapters are
DEFERRED. The existing native trial now accepts explicitly supplied synthetic Wallet/Bank initial
quantities through record/reopen/correct and backup/restore. The main minimal ordinary S-expression
book now connects explicit support → expense → retained correction → fresh candidate file/cold read.
User rejects backup/generation work as a separate prerequisite: next is a SIMPLE existing-UI
synthetic start → expense → S-expression write → exit/reopen → correction loop. Reuse existing
calculation/publication; no new UI/store framework or broad feature rebuild. Readable S-expression evidence
remains the canonical direction; production codec/store adoption and real-data operations are separately gated.
Unix is the near-term validation runtime; MirageOS support remains experimental, not an immediate blocker.
All SQLite/Irmin/Mirage trials and counterexamples retained. No authority/data migration,
global install, public service, source-side rename reversal or push. The only newly approved
dependency is main Parsexp v0.17.0; no existing dependency/compiler upgrades are intended.

## Current product direction — small household questions, AI optional

User delegates bounded development toward an ordinary, friendly household question machine,
NOT a household-specialist LLM/SLM. Deterministic operations answer small explicit questions;
Presentation explains uncertainty/next checks without inventing missing facts. AI is an optional
untrusted entrance, never a runtime/model dependency or authority. Keep owner-readable complete
evidence/export separate from least-disclosure client answers; projections themselves remain
sensitive. Current Unix progress continues; shellless/restricted Mirage composition is a future
hypothesis to qualify, not automatic confidentiality or a reason to rewrite Core.
Operational daily-use recording/save/reopen/correction remains separately gated; main S-expression
candidate staging is now implemented, not a selected-store publisher. Delegation is not
permission for dependencies, new UI/store adoption, private-data writes, recovery/migration,
operational cutover, sibling build/source copy, publication or push.

## Completed bounded task — existing synthetic UI / S-expression connection

User approves the simple UI loop, not real use or a production storage decision. D: clean b5ee924,
main 51/Book codec and ignored native UI/recording consumer; P: exact Money/quantity/source/correction,
whole proposal and existing publisher's base/currentness/uncertainty gates. R: bind existing form/view
owners to Book without lossy conversion, explicit Measure/scale/initial support and cold reconstruction.
Reuse Workbench/Recording/Notty and existing native checks. Share ONLY the existing ignored publisher's
codec-dependent document operations, with separate layout marker; no new publisher/backend/ontology,
UI toolkit, parser, harness/model, dependency install, private input or legacy-store migration.
Preserve original sources/binaries before editing. New fresh SYNTHETIC S-expression roots only; existing
text roots/layouts refuse rather than upgrade/fallback. Book v1 lacks presence; a NEW seed explicitly
has no Pantry presence, therefore UNKNOWN, not copied/erased older evidence. Require supported
Measure/scale/support and EVERY retained row; unsupported UI evidence refuses, never filters.
Select focused existing native UI/form/render checks plus cold child expense/correction/history,
invalid source/initial input before effects, conflict/uncertainty and unchanged main checks/packages.
Keep strict sequencing/fatal 8/9/11. Native returned-error checks are not physical durability.
Defer dedicated backup work/hledger/full families/performance campaigns; stable cooperative files
and parents assumed. Revisit before real-data use, new dependencies, durable Saved or layout adoption.
Completed: both existing frontends now use Book directly through Workbench/Recording, and the SAME
publisher mechanism with a codec-only parameter/distinct trial marker. All original text-generation
controls and call-local reuse controls pass unchanged. No new store/backend or lossy converter.
Both native builds, existing pure/form/render smokes and focused cold recording connections pass:
explicit 1000 → expense 900 → older-date correction 850; source/history/cuts preserved; scale/key/
missing-memo UI refusals; incomplete/duplicate/precision initial inputs before effects; no overwrite,
conflict and OLD/NEW uncertainty blocked/reconciled. Reused nine-child real PTY passes BOTH UIs,
exit/reopen/corrections/four currencies/old histories/uncertainty/missing refusal and full stty restore.
Main 180 expect/five cram, local release @install/format, 64 engine/Book hashes and exact main 51
remain unchanged. Stock and Ox already had the needed approved parser; no package installs/upgrade.
Only new fresh `sexp-v10/stores` roots used; original trial stores/private/sibling inputs untouched.
Current ignored code/README/launchers are the S-expression prototype. Old text code/binaries and
counterexamples are preserved under `sexp-v10/baseline` and prior evidence directories, not migrated.
[Verification](VERIFICATION.md#simple-s-expression-ui-loop) owns raw logs/limits. NO Saved or physical
power-loss/backup qualification inferred. Dedicated backup and hledger remain deferred.
Try NOW from the repository root: `./scratch/tui_comparison_review/try-ui notty ja --store
"$PWD/scratch/tui_comparison_review/sexp-v10/stores/simple-demo"` (one shell line). That fresh demo has
JPY Wallet 1000/Bank 0 and explicit other zeros, no Events. Enter 100, Tab, a synthetic memo, Enter;
Ctrl-Q → same command → Ctrl-E, Ctrl-U, 150, Tab, Ctrl-U, new memo, Enter → Ctrl-P original history.
[Short ignored README](../scratch/tui_comparison_review/README.md) owns complete commands. Next is
human feedback on this simple loop, NOT another backup/publisher prerequisite or full LOAM rebuild.

## Completed bounded task — minimal ordinary S-expression book / Parsexp adoption

User approves Parsexp v0.17.0 and the smallest main start-quantity -> expense -> correction ->
S-expression write/cold-read path. D: clean 33d947d, main 50 and one-package dry-run; P: exact
quantities/typed identities, Event/Movement/source/correction and independent-cut quantity gates.
R: explicit wire schema/absence, duplicate/missing/unsupported fields, Measure/scale closure,
faithful retained history/Effect/text, printer/parser connection and no-overwrite file staging.
Select a pure outer `bakhlo.sexp` codec, direct native decoding into existing Application inputs,
explicit supplied/empty/not-supplied collection states and deterministic readable printing.
First profile covers Measure interpretation, ordinary Actual metadata/Effects/corrections, exact
observation groups and zero origins ONLY; unsupported evidence refuses, not a full-household
codec or lossy richer-source converter. Preserve originals, Effect multiplicity and independent cuts.
CLI reads conditional quantities and stages WHOLE-admitted new candidates into FRESH files only;
no selected-store publication, on-open repair, overwrite, implicit support or durable Saved.
Use existing expect/cram checks for synthetic exact/unknown/history/absence/refusal and separate
process write/reopen/correction. No new model/harness/Python bridge, TUI/store adoption, upstream
source reuse/build, private input, real recording, migration or hledger expansion. Snapshot existing
packages/lock/core owners; install just Parsexp, regenerate/review lock, replay bootstrap/checks,
package/release and clean engine-only checks. Keep strict sequencing/fatal 8/9/11 unchanged.
Assume explicitly supplied stable files/cooperative parent namespaces; live capture, concurrent
selected-generation ownership, receipts, device/power-loss and full retention remain separate.
Maintenance table reviewed: source fields unchanged; new decoder's complete command coverage is
explicit and richer wire evidence refuses. Retain direct profile literals, no shared empty-source
constructor/parser framework/index refactor. Revisit before broader families, source interpretation,
physical store/publisher adoption or cutover.
Completed: ONLY Parsexp installed/locked (50 → 51); existing versions/compiler and all 70 captured
Domain/Application hashes unchanged. Native initial/expense/correction/reopen exact/unknown/history,
independent cuts/forward refs, signed 180-bit quantities, typed identity/text/control/invalid-UTF8
bytes, absence, duplicate/missing/unsupported and whole-proposal refusal pass. Fresh CLI cold staging
retains originals; existing targets/symlinks, malformed flags and bad sources refuse. A failed create
attempt other than an existing collision is explicitly UNCERTAIN, not rollback/retry permission.
Main 180 expect/five cram, locked bootstrap, forced package tests, local release @install, pinned
formatting, fresh engine-only/no outer artifacts and nonexistent-LEAN/LAKE checks pass.
[Verification](VERIFICATION.md#minimal-ordinary-s-expression-book) owns negative runs and limits;
raw logs/baselines are ignored in `scratch/ordinary_sexp_review`.
Try the [synthetic S-expression walkthrough](../examples/ordinary-sexp/README.md). No private inputs,
original trial-store changes, UI/store adoption, real recording, receipts/selected publisher,
fsync/power-loss qualification, hledger, migration, sibling build/source copy, release or push.
Latest user direction above supersedes backup/publisher-first scheduling: connect the existing
synthetic UI directly, retaining its earned refusal/uncertainty gates. Do not rebuild all LOAM
features or infer production Saved from successful restart. Full-household schema/physical layout
and any real-data cutover remain separate decisions.

## Completed bounded task — ordinary-use loop / explicit synthetic initial quantities

User approves finishing a minimal ordinary Bakhlo loop, not rebuilding every LOAM feature.
Question: can BOTH existing native trials start from explicitly supplied Wallet/Bank quantities,
record/reopen/correct and preserve original support/history without overwriting existing stores?
D: clean 591f6d5, paired native consumers and fixed-seed profile; P: exact quanta/Measures,
whole admission, old Bank UNKNOWN, sealed proposals, receipt/currentness and closed backup gates.
R: signed/zero/huge initial input, complete per-currency supply, narrow new support shape and
cold reconstruction. Reuse Money/Workbench/Recording and SAME native recording checks; no new
model/harness/dependency/UI/store or codec. Preserve source/binary baselines before edits.
Bound to fresh SYNTHETIC trial roots, two existing locations and four existing versioned Measures;
all eight initial values must be explicitly supplied. Initial assertions have independent empty
cuts; no balancing Events, guessed dates, missing -> zero or on-open support change. Keep old
seed bytes/profile and refusal controls intact; existing targets refuse. Select native stock/Ox
builds/checks, exact independently expected quantities/retained bytes, malformed/missing/duplicate/
precision refusal before effects, cold children and existing backup/restore connections. Reuse
main checks; no broad new I/O campaign or sibling/private execution. Maintain original artifacts.
Revisit before arbitrary loci/currencies, support editing, canonical codec/store adoption, actual
household writes or cutover; successful synthetic restart is not durable Saved.
During qualification the ordinary @all check fails on the isolated experiment's missing Parsexp;
root Dune excludes scratch but not experiments. Resolve this concrete dependency-isolation gap:
exclude experiments from main traversal and give trial CI/docs an explicit local --root. Reuse
main/locked checks and independent trial-root inspection; install nothing, keep warnings/flags.
Completed: both native builds/connection suites pass exact signed/zero/180-bit initial quantities,
complete-supply/precision/duplicate refusal before effects, custom expense/income/transfer/cold
non-last correction, retained original support and complete backup/fresh restore. Both native
entrances pass 18 argument/input controls without target creation; existing targets unchanged.
Reversed explicit input order yields identical stock/Ox initial bytes and cold summaries. Default
complete proposals remain byte-identical to preserved binaries; both pure/view smokes and main
175 expect/four cram/release @install pass. Exact 50/lock/Store/Backup/Locale stay unchanged.
Sources/binaries/raw logs and failures retained ignored in `initial-v9`; [Verification](VERIFICATION.md#explicit-synthetic-initial-quantities)
owns limits. No private input, renderer/keyboard changes, new PTY or physical durability claim.
Try a FRESH synthetic store using `try-ui init --store PATH` plus one `--initial CODE WALLET BANK`
for EACH of JPY/EUR/USD/ILS, then either existing UI. [Ignored README](../scratch/tui_comparison_review/README.md#explicit-initial-quantities-synthetic-only)
owns a complete example. No flags means the old explicit demo seed, never a partial-list fallback.
Next: human synthetic ordinary-use feedback; choose the smallest canonical S-expression profile/
codec and publication failure model before promotion to the main ordinary-use path. No automatic
real-data recording, Store/UI adoption, recovery/migration, full LOAM parity or hledger work.

## Deferred design — readable schema and safe data interchange

User approves prioritizing long-term readability/maintenance/extension, hledger-compatible
journal export and trustworthy imports. Question: how can outer interchange preserve declared
meaning without becoming another authority or silently accepting lossy/ambiguous conversions?
D: clean fbd6d84, synthetic S-expression candidates and isolated codec trial; P: S1–S10, earned
currentness/date/quantity/proposal gates and documented journal losses; R: exact wire fields,
export representability/escaping, source-specific import mappings and independent compatibility.
Select a documentation-only profile/refusal review in existing architecture owners, not a new
parser/import framework, fixture pipeline, dependency or private-data read. Keep named shallow
records, explicit absence, versioned wire schema and deterministic readable formatting.
[Architecture](ARCHITECTURE.md#safe-data-interchange) owns the contract: one-way current journal
projection with explicit loss scope; retained-original staged imports, no guessed facts or
content-only deduplication, whole-candidate admission and fresh publication gates.
Assume explicit supplied mappings/interpretation; do not assume hledger availability, a bank
format, external stable IDs or a complete household codec. Completed the scoped design contract
and pending qualification cases; exact diff, new link targets/anchors and whitespace checks pass.
Implementation/dependencies remain unchanged. [Verification](VERIFICATION.md#safe-data-interchange-design-review)
owns limits; no executed hledger, import/export roundtrip, main-suite or production-safety result is inferred.
DEFERRED behind the ordinary-use loop by the latest user decision. Retain these preservation
requirements, not an export-first implementation schedule. When resumed, fix the hledger target
version/escaping/account/commodity profile and check with an independent reader before claiming
compatibility. Imports need a named source format and explicit conversion rules. Revisit before
production codec/dependency adoption, private access, source-specific parser work or migration.

## Completed bounded task — delimiter-free plain-text comparison ONLY

User finds the S-expression candidates visually heavy and requests a plain-text version without
parentheses/brackets/braces. D: clean 1a2ce2b/four public synthetic candidates; P: retained evidence,
cut ownership/unknown/precision/policy/provenance and no-parser/writer/migration boundary;
R: lighter readable spelling without semantic deletion. Hand-author four paired `.txt` examples
with explicit keyword/end boundaries, quoted exact strings, independent cuts and explicit empty/
not-supplied states. A nonempty named record explicitly supplies its collection; absence is NEVER
implicitly empty. Preserve original candidate files, record/effect order and all fact payloads;
compare statically/manually, not a new parser/translator/harness or grammar adoption. No private
access, dependencies/code/DTO/writer/migration, clipboard export or push. Syntax preference was
reopened for this comparison; the latest user decision above confirms S-expressions. Neither
these fixtures nor syntax selection authorize production codec implementation or migration.
Completed [four paired plain-text fixtures](../examples/plain-v1-candidate/README.md): record
keywords/end markers replace structural nesting; empty/not-supplied declarations remain explicit.
Each pair matches exact quoted/numeric literal sequence; manual field/state/reference review,
no delimiter/basic block-balance, intended 01/04 loss diff and link/whitespace checks only.
These are NOT semantic decoding/roundtrip/refusal execution. Original S-expression fixture
bytes, code/tests and main exact 50/lock unchanged; no original/private/upstream access.
User has now selected S-expressions; these plain-text fixtures remain comparison evidence,
not a second codec to maintain. Review the selected schema next; no production parser/writer,
migration or package installation is newly authorized. Preserve evidence-generation obligations.

## Completed bounded task — synthetic v1 evidence-generation fixtures ONLY

User affirms S-expression direction and clarifies: selected current book is a self-contained
CANONICAL EVIDENCE GENERATION, never flattened current answers. Retain superseded Events,
explicit relations, observations/cuts and necessary policy/provenance even if current views
omit them. User requests a FEW synthetic fixtures before implementation; explicitly NO
parser/writer/migration. D: clean e58594a/current synthetic examples; P: semantic contract and
earned correction/date/relation/discharge/cut/unknown models; R: reviewable v1 field spelling,
collection absence, reference closure and receipt scope. Select four hand-authored candidate
.sexps + one review README: retained evidence, reordering/forward refs, precision/absence,
and deliberately flattened missing-reference refusal. Reuse existing model/test expectations
as explanatory oracles, not new executable adapters/harness/proofs. Check quotations/delimiters,
manual field/reference/arithmetic correspondence, links/whitespace and unchanged dependency/
code boundaries. No dependency installation, private read/copy/fixture/clipboard export,
upstream execution/source reuse, codec/DTO/API adoption, writer or migration. Collection not-
supplied versus provided-empty is explicit; full-family/receipt/config parity is NOT claimed.
Revisit only after user reviews the candidates; dependent query examples do not define retention.
Completed [four synthetic candidates + Japanese review notes](../examples/sexp-v1-candidate/README.md).
01/02 retain identical fact payloads with changed declaration order; 03 covers exact huge quanta,
Measure separation/opening reference and explicit empty/not-supplied/nonzero-with-unknown-amount;
04 removes ONLY 01's e1 (plus explanatory comments), keeping its dangling relations/cut/provenance
as an expected-refusal counterexample. No missing Event is repaired from an archive/derived view.
One-off quotation/parenthesis checks passed; 01/02 atom/string/delimiter multisets match and
01/04 diff matches intended loss. Manual expectations cite existing date/relation/discharge/
quantity oracles; no AST decode, whole semantic admission, roundtrip, refusal execution or main
suite result inferred. [Verification](VERIFICATION.md#synthetic-s-expression-v1-candidates)
owns limits. Main exact 50/lock, executable/interfaces/tests and private/upstream sources untouched.
Next: USER REVIEW of candidates/field states/receipt and full-family scope ONLY. Do not start
parser/writer/migration or install Parsexp on the strength of these fixtures or earlier roadmap.

## Current design decision — S-expression syntax / long-term boundaries

User selects S-expressions and asks for long-term design, not an immediate codec/install/cutover.
D: clean dba532e, synthetic comparison and public Parsexp dependency facts; P: semantic contract,
logical fact-book and publication/receipt boundaries; R: stable explicit wire schema, faithful
whole-family/interpretation mapping, original-result receipt scope and retention/physical costs.
Select a short architecture recommendation; no new model/harness/private reads/dependencies.
Recommend minimal Parsexp at the outer adapter, explicit versioned unadmitted Wire DTOs -> whole
model admission, deterministic printer and structured refusal. Known schema rejects duplicate/
missing/unsupported fields; do not use internal deriving/defaults as the storage contract.
Currentness remains relational, retained originals/effect occurrences/independent support/policy
and interpretation remain explicit; comments are not the only home of necessary information.
Selected book means a self-contained canonical EVIDENCE generation, not flattened current
state: all retained in-scope facts/relations/cuts/policy/provenance survive current projections.
Archives/receipt evidence remain retained, not mandatory ordinary reads of every ancestor.
This is a layout recommendation, NOT an adopted writer/retention rule or permission to discard
existing trial guards/generations.
Receipt contracts must still bind original candidate/base and retain original-result evidence;
Event-only mapping is not asserted sufficient. Upgrade is explicit old -> fresh checked target,
not on-open mutation; current generation/ownership and honest uncertain outcomes gate writes.
[Architecture](ARCHITECTURE.md#selected-s-expression-direction--long-term-boundaries) owns details.
Next is ONLY the synthetic v1 fixture review above. Exact fields/absence/interpretation and
receipt scope need review; codec/roundtrip work and parser dependency installation are paused
by the user's explicit no-parser/writer/migration boundary.
No external review result assumed; LOAM remains sole authority, no original/migration writes.

## Completed bounded task — pasteable syntax comparison

User requests a standalone memo for desktop ChatGPT comparing S-expressions + minimal Parsexp
versus custom fact text. D: clean df1da54/public package dependency metadata; P: semantic
contract and logical fact-book review; R: fair equivalent examples, marginal dependency versus
owned lexer/parser costs and decision criteria. Select synthetic-only documentation; do not
read/reuse private copies, payloads or usage results. Compare shared schema/admission separately
from syntax/publication, label assumptions/unmeasured costs and request an independent decision,
not confirmation of pit's earlier Parsexp preference. No parser/format/dependency adoption,
private clipboard export, main-suite rerun, migration or original access in this slice.
Completed [standalone Japanese prompt](FORMAT_COMPARISON_PROMPT.ja.md): equivalent fictional
Event/correction/observation/request bindings, explicit interpretation and schema limits;
checked Parsexp v0.17.0's existing-dependency closure versus full Sexplib's additional Num.
Existing parser/PPX availability is not a complete codec; costs/portability remain unmeasured.
Syntax delimiter/link/whitespace and synthetic-only scope checked; no installation/code/private
reads. User subsequently selects S-expressions; no external answer was supplied or presumed.
The comparison remains historical design input, not parser qualification or migration permission.

## Completed bounded task — stopped private capture / representation comparison

User confirms `/Users/user/Projects/moko/loam-data` and agrees to stopped capture. Question:
can one scoped read-only capture of current household.loam plus Measure-scale metadata support
representative movement/correction/observation format comparison without lost/guessed evidence?
D: clean 21ca9c1, source/format review and native Envelope/Read; P: whole frame/profile gates,
exact quantities/cuts/history and original/private boundaries; R: coherent stopped acquisition,
actual profile coverage and readability/retained-field correspondence. Select one small ignored
native OCaml consumer using EXISTING Envelope/Read, not Python/generated payloads/new model,
parallel maintained harness or wider parser. Qualify only capture edges on fresh synthetic
files before private access: unchanged exact copies, missing/malformed/symlink/existing-target
refusal and deliberate inter-read change. Scope original reads to current household.loam and
config/measure-presentation.tsv (preserve absent metadata as absent); no root discovery/legacy
fallback, original lock/write/recovery or sibling build/source copy. Assume cooperative stopped
writers/stable paths; compare metadata+full bytes again after copying, refuse any change and
preserve incomplete scratch artifacts. Private files/results remain ignored 0700/0600, never
fixtures/commits/public payloads. Unsupported profile refuses answers/import; retain raw opaque
sections rather than strip evidence. Excerpts/sketches are NOT a codec/migration/household
admission. No storage/UI/dependency adoption, canonical writer, real migration or cutover.
Revisit before live capture, extra configs, format selection or actual information-preserving
migration; a stopped same-host comparison copy is not disaster backup or durability proof.
Executed: no named LOAM process observed; all seven bounded synthetic capture controls passed,
then stopped scoped capture with stable repeated full bytes/stat metadata (excluding atime).
Existing native read profile ADMITTED only its declared Actual/four-support/origin scope, not
all other families/config. Existing synthetic fixture exercised private-view rendering first;
private current/candidate excerpts or explicit no-example outcomes are now in ignored
`scratch/canonical_evidence_review/private-v1/comparison.private.md`. No private values, IDs,
counts, dates, names, source hashes or raw errors emitted/published. Raw household + scale
bytes/absence and unadmitted payloads are retained; no quantity answers, grammar/codec or
migration proof claimed. Native consumer uses fatal 8/9/11 and strict sequencing; main/50/lock
and pinned sibling source remain unchanged. [Verification](VERIFICATION.md#stopped-private-representation-comparison)
owns scope/controls. Next: choose logical fact-book structure with explicit relations and
coherent interpretation/support/policy before codec/store/UI work; use private excerpts locally
and public synthetic examples for discussion. Current source capture is not a perpetual live
mirror or authorized future write target. Original/cutover permissions remain separately gated.

## Completed bounded review — canonical evidence / inherited format

User requests identifying retained meaning versus derived values, publication mechanics and
format debt before more prototype work. D: clean c7da7a3/current sibling source
f82f4c45498ce9b3c51a76acb7189588a5f74718; P: semantic contract, earned history/cut/support/origin
gates and upstream blueprint/evidence maps; R: family sufficiency, actual authority path,
wire/protocol identities, export losses and candidate choices. Select nearest source/doc owners,
not a new parser/model/theorem/audit runner or I/O campaign. Maintenance requires no refactor;
future field/profile changes reopen adapter coverage. No upstream execution/build/modification/
source copy, operational/current-user reads/copies, private fixtures, migration/cleanup or push.
Completed source-only classification: 13 registered payload families retain facts/observations,
routing/classification/write policy and historical support. ASSERT is independent observation;
opening quantity is already in Actual; groups need cut ownership, not stable household identity.
Request -> original Event is publication provenance; settlement Measure/quantity is independently
evidenced; external Measure scale is interpretation metadata. No actual field is proven unused.
Confirmed costs: scalar-length outer framing, old Scheduled terminal substreams, stale upstream
canonical-path summaries/explicit legacy entrances. Actual v1-v4 are actively emitted, not all
old compatibility. Current journal views lose original/date/support/policy evidence and plain
export loses keys; no universal hledger impossibility claim. Our all-ancestor snapshot trial
is also not a household requirement; preserve evidence/receipts, not automatically its layout.
All 39 selected source/doc hashes/revision/clean status and Bakhlo 50/lock unchanged; doc links/
whitespace checked. No compiler/test rerun or private access for doc-only work. Ignored scratch
retains source metadata/digests only. [Architecture](ARCHITECTURE.md#canonical-evidence--inherited-format-review)
owns classification/candidates; [Verification](VERIFICATION.md#canonical-evidence--inherited-format-review)
owns source evidence/limits. Two synthetic explanatory contrasts reuse earned history/cut laws.
Next: compare current lossless container versus simpler owner-readable fact text on a few
movement/correction/observation examples. User accepts read-only real-data reference in discussion;
before PRIVATE execution, name examples/source and resolve coherent capture + needed scale/config
metadata. No stale-copy reuse, assumed running/data version, payload disclosure, rich-evidence
filtering or promotion of the partial reader to full importer; copies/results stay ignored.
Further trial I/O/UI/initial setup is PAUSED pending this decision. User now explicitly allows
representation migration IF a better design is demonstrated: old LOAM wire compatibility is
not a permanent constraint. This is conditional design permission, not immediate original
writes or format adoption. First select the representation and lossless transition scope,
preserve originals/complete private copies, qualify retained facts/support/policy/interpretation
and receipt/correction correspondence plus failure refusal, then explicitly select cutover.
No guessed missing evidence, identity normalization disguised as migration, dual writes or
indefinite compatibility/synchronization. Source path/stopped scoped capture were subsequently
resolved in the bounded task above, not inferred from defaults. No new grammar/codec/store/
journal authority, actual migration/cleanup, real writes or cutover is selected by this permission.

## Completed bounded task — native Unix I/O failure review

User approves continuing with synthetic I/O/space/namespace failure qualification, not real
recording or storage adoption. Question: do existing Store/Backup/Recording consumers retain
original bytes and honest refusal/uncertainty when native write/fsync/close/rename/unlink fail,
including a short write and cleanup failure? D: clean 27de66d, checked Unix wrappers and both
native CLIs; P: whole ancestry/profile, exact/support/history, receipts and closed-copy/kill
controls. R: actual Unix error-return connections, cleanup precedence, post-selection and
post-marker-removal ambiguity, safe space-error coverage and retention decision.
Select existing native recording checks/CLIs plus a small ignored, child-only Darwin C
interposer: actual EBADF/resource-limit failures separately from injected EIO/ENOSPC returns.
No disk filling, mounts/VM/global settings/dependencies/Python/new ledger model or broad fault
campaign. Match only explicit fresh synthetic paths; preserve current sources/images first.
Reuse independent exact quantities/fingerprints and read-only cold reconciliation. A genuine
namespace error uses an existing checkpoint on a newly created test store only. Record exact
error/exit/log hits; an untriggered injection is a failed control, not a pass. Both consumers
retain terminal feel, main engine/50/lock and current-user/operational data untouched. Stable
cooperative parents/immutable artifacts remain assumptions; no security, physical ENOSPC,
device/power-loss/durable Saved, cleanup/resume, automatic pruning or permanent retention
policy. Revisit before real data, lifecycle/recovery/retention adoption or another host.
Completed: both native builds and 70 selected cases (24 publication/26 backup/20 restore;
64 failure/6 short-write success) pass. Genuine child resource-limit EFBIG after 7 bytes,
kernel EBADF with deliberate invalid arguments and actual rename ENOENT are distinct
from injected EIO/ENOSPC. Original bytes, pending/frozen drafts, OLD/NEW read-only receipts,
missing/incomplete refusal, marker-blocked restore, exact complete copies and no overwrite/
resume survive. Paired primary+close failures retain BOTH causes. Completed artifacts after
seal/source-close/final-sync errors independently verify but remain Uncertain, never Saved;
post-marker-removal failure can leave a complete readable target. First probe consumed a
read-only LOCK fingerprint close before publication; preserved v1, target only the O_RDWR
lease handle, fresh v2 passes. Scope-qualified v3 repeats all 70; test entrances check scope
before payload/fingerprints, require fresh empty publication roots and refuse malformed
arguments before effects. Both deliberate nonmatching probes fail the native expectation
(no false pass); scope/reused-root/argument refusal and final native checks pass. Existing
mixed/history/180-bit/old UNKNOWN/lease/SIGKILL controls and main
175 expect/four cram pass; main exact 50/lock/Store/Money/Workbench and full proposals unchanged.
Sources/images/exact logs/partial and complete ambiguous artifacts retained ignored in `io-v8`.
Retention decision: preserve ALL generations/originals/receipts and refused artifacts; no
pruning/compaction/cleanup/adopted policy. Current mixed family has 35 complete envelopes /
169,478 bytes; this is NOT a lifetime budget. [Verification](VERIFICATION.md#native-unix-io-failure-boundaries)
owns precise scope and remaining physical/handle/lifecycle gaps. No user-store/operational
reads or writes, disk filling, mounts/VM/dependency/global changes or new Saved claim.
The former next step, SYNTHETIC initial balance/locus setup, is paused for the representation
review above. Actual physical space/device faults, parent lifecycle, recovery/retention and
durable acknowledgement still need their own decisions/qualification before real recording/store adoption.

## Completed bounded task — synthetic closed backup/restore

User approves the next backup/restore step, NOT real-data use or store adoption. Question: can
an explicit closed complete trial family preserve all selected ancestors/receipts/original
bytes/support, restore ONLY to a fresh namespace, reopen/correct in both UIs, and refuse damage
or interruptions without overwrite/fallback? D: clean e581a6e, paired native consumers/reuse
Store; P: whole source/profile/history, exact quantities/unknown, namespace-bound tokens and
closed-copy control. R: coherent leased family capture, independent backup completion/integrity,
new-target restore phase, lost acknowledgement/process death and native CLI connections.
A small consumed outer Backup owner copies EXISTING Store files, not another backend or codec.
Acquire publisher-compatible LOCK for source capture; never close another LOCK fd while that
POSIX process lease is held. Exact all-ancestor/profile/regular-file/closed-set checks precede
target creation. Backup-only completion seal binds head/file inventory/length/digest (accidental
corruption detection, NOT authentication/security/durable Saved); full copied bytes compared.
Restore into nonexistent dedicated trial store only; own in-progress marker blocks publication
until successful complete validation. No source mutation/cleanup, current-store replacement,
implicit init/migration, orphan salvage or blind retry. Cooperative stable namespaces, immutable
backup artifacts and stopped/cooperatively leased source; live/uncooperative capture deferred.
Select SAME native recording consumer/independent quantity checks and quiet-drained PTY loop,
not a new harness/model/theorem/dependency/Python bridge. Include preserved mixed originals/
receipts/180-bit/old Bank unknown, corruption/missing/extra/symlink/Busy/existing-target refusal,
returned copy-phase failures, one real create-file collision and real process-kill controls.
Maintain main engine/lock, existing Store and UI palettes/focus; no maintenance consolidation
trigger. Preserve sources/images; tests use fresh synthetic names, never read/reset/copy user's
current or operational data. Backup namespace remains ignored/same-device trial, no encryption,
off-device disaster recovery, power-loss, Mirage/other-host, physical failure campaign, recovery
or Saved qualification. Revisit before adopting retention/format/recovery, live backup or real
data. Completed: shared native Backup CLI in BOTH binaries, source lease/full all-ancestor
capture, last completion seal, new-target marker/current-last copy and independent exact
validation pass. All prior native expense/transfer/income/Tab/refusal/receipt tests still pass.
Closed mixed copies retain exact files, old original receipt != current, original history,
180-bit and old Bank unknown; restored-only correction leaves source/archive unchanged.
Eight damage controls, existing target/scope/orphan/symlink refusal, cross-process retained
POSIX lease/Busy, prewrite/postwrite returned errors, actual file-create EEXIST and real
SIGKILL backup/restore controls pass; unfinished restored UI blocks recording. Completed
artifact after lost acknowledgement remains ambiguous, not proof of failure or Saved.
Reused quiet-drained restore PTY v2 passes five children/two backup-restore cycles across
both UIs/ja/en, mixed original history and unchanged source; Main check/exact main 50/lock/
Store/Money/Workbench and exact stock/Ox proposals/backup/restored-answer equality pass.
Initial parallel main-check/stock-build hit Dune's lock; serialized rerun passes. Initial PTY
Tcl `args` parameter nested native argv (refused before backup); rename/fresh v2 passes.
Failures/baseline/images/artifacts retained ignored in `backup-v7`; no current-user/operational
input read/copied/mutated. [Verification](VERIFICATION.md#synthetic-closed-backuprestore) owns
precise evidence/limits. No source cleanup, live/off-device recovery or operational adoption.

Quit UI, explicitly select your SYNTHETIC source; `.../try-ui backup SOURCE NEW_BACKUP`,
`.../try-ui check-backup BACKUP`, `.../try-ui restore BACKUP NEW_STORE`, then
`.../try-ui bonsai ja --store NEW_STORE` or Notty/en. All paths explicit; existing targets
refuse, no overwrite/resume. Store paths remain direct `recording-v3/stores` children, backup
paths direct `recording-v3/backups` children. [Ignored README](../scratch/tui_comparison_review/README.md)
owns full example and conditional-copy caveats. The bounded native error-return/retention
review is now completed above; physical device/space and durability remain unqualified.
Human synthetic restore remains available; further initial balance/locus setup is paused for
canonical evidence/format review above, before real recording or store/UI decisions. Do not
manually clear uncertainty markers, replace current data, delete originals or infer durability.

## Completed bounded fix — TUI Tab order

User reports Operation/Date focus jumping contrary to visual order. D: clean 79beac5;
both renderers show Kind -> Date -> Currency, shared Interaction still uses Date -> Kind.
P: route-specific pickers, pure key collection and unchanged publication/unknown gates.
R: forward/backward cycles must match visible fields for Expense/Transfer/Income in both UIs.
Fix only shared focus edges; retain initial Amount focus/layout/data/recording guards. Reuse
native smoke with explicit independent expected cycles and inverse Tab/Shift-Tab checks;
first reproduce the mismatch, then rebuild BOTH consumers. No new harness/model/dependency,
user-store reads/writes or maintenance refactor. Revisit when visible form order/fields change.
Both consumers FIRST fail the added expected-order check on the old edges; after the fix,
both isolated builds/native smokes pass all five routes x4 currencies x2 languages, full
forward/reverse/wrap/inverse cycles and unchanged draft/record bytes. Existing smoke/geometry
and complete stock/Ox proposals pass; prior proposal output is byte-identical after removing
only the new check's success line. Workbench/Recording/Store/renderers/Money/Locale/lock hashes
unchanged. Evidence retained ignored in `tab-order-v6`; no main check/physical PTY/storage
failure campaign rerun for this focus-only fix. [Verification](VERIFICATION.md#tui-tab-order-fix)
owns the result. Restart either UI to pick up Operation -> Date -> Currency (then visible route
fields -> Amount -> Memo -> History; Shift-Tab reverses). Existing records need no init/reset.

## Completed bounded task — synthetic TUI income

User approves adding Income to BOTH existing UIs, preserving their feel. Question: can explicit
income to Wallet or Bank record/reopen/correct beside expenses/transfers without rewriting
old bytes, losing provenance or creating quantity support? D: clean 10c7ec3, native consumers,
main 50/lock and prior sources; P: exact balanced Effects, whole-profile/currentness/receipt,
original history, route/currency locks, independent support/unknown and drained PTYs. R: income
counterpart/destination collection and retained-shape qualification, mixed cold correction and
uncertain publication. Pure Workbench owns `income-source` -> Wallet/Bank as two opposite
same-Measure Effects (negative counterpart, positive receiver), NOT a Core income/account/party
ontology. This is explicitly supplied SYNTHETIC flow, not guessed salary/provider/tax evidence.
Income source has NO invented origin/balance/total; neither activity nor income establishes
missing Bank support. Keep both old seed profiles/default path unchanged; no init/migration.
Existing Recording/Store own effects; Locale stays pure. Ctrl-T cycles three operations;
Income has a destination picker; corrections lock operation/destination/currency as before.
Selected instruments: extend SAME native smoke/recording checks, retain independent expected
quanta/conservation and existing refusal/OLD/NEW receipt controls; reuse quiet-drained PTY for
cross-UI/language mixed recording/correction/history. No new model/theorem/harness/package,
Python bridge or broad campaign. Maintenance triggers do not call for engine consolidation.
Preserve sources/images first; never inspect/reset the user's current store or operational data.
All controls use fresh synthetic names. No FX, richer income categories, canonical UI/store,
backup/recovery, durable Saved, syscall/power-loss/Mirage qualification, dependencies or push.
Revisit before broader counterpart/routes, changing correction destinations, support/policy or
real-data use. Completed: both native builds, 4 currencies x2 receivers x2 display languages,
exact signed/conserved Effects/180-bit, whole original/correction/route qualification, old
Bank/source UNKNOWN and read-only OLD/NEW reconciliation pass. Native cold mixed histories,
non-last income correction and session/detail behavior retained. First stock build refused
`effect` as a reserved 5.3 test-variable name (Ox 5.2 accepted); renamed, no compiler/warning
change. Reused quiet-drained income PTY passes eight children at 100x25 across both UIs/ja/en:
Wallet/Bank income, mixed expense/transfer, repeated non-last correction/two original versions,
EUR precision refusal/correction, detail IDs, visible OLD/NEW uncertainty and full terminal
restore. Original transfer eight-child and expense nine-child PTYs also pass on fresh stores.
Main check, exact stock/Ox complete proposals/cold answers and main 50/lock/Store/Money
preservation pass. Sources/images/controls/failed compiler evidence retained in ignored
`income-v5`; [verification](VERIFICATION.md#synthetic-tui-income) owns precise scope/limits.

Restart the existing trial (Ctrl-Q then same `.../try-ui bonsai ja` or `.../try-ui notty en`).
Ctrl-N empty new, Ctrl-T until Income; Shift-Tab from Amount selects To, Left/Right Wallet/Bank,
Tab back to Amount, positive synthetic amount + memo, Enter record. Ctrl-E corrects selected
row; operation/destination/currency locked, Ctrl-P cycles original history. Existing records,
seed/init bytes and default path unchanged; do NOT init/reset your existing store. Both UIs
still show selection/uncertainty, not durable Saved. Next: human income use, then a separately
bounded backup/restore and actual failure review before real data; no automatic implementation,
canonical store/UI adoption, recovery/cleanup or operational authority change.

## Completed bounded task — same-currency synthetic TUI transfer

User approves adding transfer to BOTH existing UIs, retaining their feel and moving long
internal IDs to an explicit detail view. Question: can explicit Wallet/Bank direction and
amount record, cross-UI/language reopen and correct without changing old expenses/support,
losing original route/memo/history or inferring a balance from transfer activity?
D: clean 36ae42f, current ignored recording consumer, main exact 50/lock and 175 expect/four
cram; P: exact ordinary-Movement/proposal gates, whole profile/receipt/currentness, ja/en
and cold expense/history/failure checks. R: endpoint collection/whole reconstruction, same
Measure on BOTH Effects, self-transfer refusal, correction route binding, independent Bank
support and normal/detail presentation. Owners: pure Workbench maps the narrow UI routes
onto EXISTING Effects (no Core transaction-kind/account ontology); existing Recording/Store
retain publication. NEW explicit synthetic provisions add Bank zero origins for each trial
currency. Old supported expense seeds remain byte-readable with Bank UNKNOWN, never zero
filled/migrated/reinitialized. Same known old support profile may retain newly proposed
transfers without gaining Bank support. Correction locks currency AND route for this bounded
entrance; kind/direction changes require a new empty draft. Only Wallet <-> Bank, no FX,
income, balance permission or new locus catalog. Pure Locale stays shared; detail toggle
changes presentation only, keeping full identities/generation/receipts internally.
Selected instruments: extend SAME native smoke/recording checks and drained PTY consumer;
independently expected per-locus quanta, per-currency conservation, mixed expense/transfer
bytes/history, old-seed unknown, shape/route/precision/stale refusal and one transfer OLD/NEW
uncertainty connection. Reuse existing engine oracles, not another model/framework/package,
Python bridge, theorem or large campaign. No maintenance consolidation trigger; unchanged
parsers/identities/arithmetic/storage; keep both original palettes and main dependencies.
Preserve current sources/images before edits; do not read/reset the user's current trial
store or operational inputs. Tests use freshly named synthetic stores only. No new UI,
canonical format/store adoption, recovery/backup, real data, Mirage build, global install or
push. Revisit before broader routes, correcting routes/currencies, real data or physical
failure/retention qualification. Completed: shared Workbench/interaction and BOTH renderers
now collect Expense/Transfer and explicit From/To; same-currency opposite Effects, self/route/
precision/currency/stale refusal, mixed original history and cold reads pass. Correcting a
non-last row now keeps its lineage selected rather than jumping to the final root. Long IDs
are normal-view hidden, full in Ctrl-G detail/session diagnostics; toggling never changes
records, drafts or pending/receipt gates. Native four-currency/two-direction/two-language and
180-bit controls, mixed recording/older-seed UNKNOWN even at net zero and OLD/NEW uncertainty
pass. Actual quiet-drained 100x25 PTYs pass both-direction JPY and EUR cross-UI/language
record/reopen/correction/history, independent endpoint/self/locked-route controls and detail
IDs; original nine-child expense PTY also passes. Main 175 expect/four cram and stock/Ox exact
mixed proposals/cold answers pass; exact 50/lock/Store/Money unchanged. First transfer PTY
assertion did not drain all Notty frames; failed evidence retained, quiet-drained rerun passes.
No real/current-user-store read or mutation, recovery, Saved, actual syscall, power-loss or
Mirage qualification. [Verification](VERIFICATION.md#same-currency-synthetic-tui-transfer)
owns precise evidence/limits; `transfer-v4` retains sources/images/checks/PTYs.

Restart the existing trial UI to use the new binary: `.../try-ui bonsai ja` or `.../try-ui notty en`.
Ctrl-N empty new, Ctrl-T expense/transfer, Ctrl-B reverse empty transfer (or Tab to From/To,
Left/Right independently), Enter record, Ctrl-E correction, Ctrl-P original history, Ctrl-G
internal detail. Default path and old expense records are unchanged; old Bank is UNKNOWN, not
filled with zero. For known SYNTHETIC Bank origins, explicitly init a fresh named store:
`store="$PWD/scratch/tui_comparison_review/recording-v3/stores/transfer-demo"`, then
`.../try-ui init --store "$store"` ONCE and `.../try-ui bonsai ja --store "$store"`.
Never reset/migrate the existing store for a demo. [Ignored trial README](../scratch/tui_comparison_review/README.md)
owns full controls. Next: human transfer use, then a separately bounded income entrance;
backup/restore and actual failure qualification before real data, not automatic adoption.

## Completed bounded task — synthetic TUI record/reopen/correction

User approves connecting the EXISTING Unix text publication experiment to BOTH native
TUI trials. Keep ja/en switching and its pure shared display boundary; richer switching,
settings persistence, other UIs and Mirage integration are deferred. Question: can Notty
record, exit, Bonsai reopen in another language, correct, exit and Notty inspect original
history without false Saved, erased load failures or blind uncertain-result retry?
D: clean 492efde, main exact 50/lock, paired money-v2 UIs and current reuse Store available.
P: whole admitted proposals, explicit four-currency scales/support, exact stock/Ox bytes,
retained history, fresh expected-head/receipt and interruption gates. R: whole synthetic
UI-profile reconstruction/identity freshness after restart, shared publication outcomes,
draft retention on failure, receipt reconciliation versus current generation, history view
and genuine cross-UI cold processes. Owners: pure Workbench reconstructs/qualifies the
narrow expense projection; existing ignored Store owns Unix effects; a small consumed
trial recording owner connects them. Locale remains pure/Unix/UI-framework-free; keyboard
help stays TUI-specific, not a universal UI convention. Explicit synthetic provision,
trial-owned namespace only; opening never initializes/repairs/falls back. Reuse the SAME
native smoke/PTY consumers and targeted existing Store fault hooks, not another model,
framework, package, Python bridge or broad campaign. Check four currencies/huge exact
amounts, cross-UI/language cold reopen/correct/history, conflict/load refusal and OLD/NEW
uncertainty without blind retry. Preserve current sources/images before editing. Main
compiler/lock/dependency directions and all old stores/trials stay unchanged. No real data,
canonical storage/UI adoption, live backup/recovery, power-loss/Saved, Mirage build or push.
Revisit before actual syscall/namespace/recovery qualification, permanent adoption or real
recording. Completed: BOTH native frontends consume unchanged reuse Store; explicit provision,
whole UI-profile cold reconstruction, fresh publication, original-history cycling and read-only
receipt checks pass. Initial deterministic request-ID collision exposed by conflict check was
fixed with outer Unix trial entropy allocation, not UI allocation or a new package. Native
4x2/180-bit/failure connections and real drained PTYs pass Notty ja -> Bonsai en correction ->
Notty ja recorrection -> Bonsai history in both languages; OLD uncertainty remains blocked,
NEW receipt reloads independently selected current evidence. Main 175 expect/four cram,
exact stock/Ox proposals/cold answers and unchanged 50/lock/Store controls pass. No real data,
Saved, actual syscall/power loss or Mirage qualification. [Verification](VERIFICATION.md#synthetic-tui-recordreopencorrection)
owns retained controls, initial failures, terminal/evidence limits. Broader language switching,
other UIs/Mirage and settings persistence stay deferred; pure Locale boundary is reusable.

Try from repository root (SYNTHETIC ONLY; >=64x25 terminal):
`./scratch/tui_comparison_review/try-ui init` ONCE, then `.../try-ui notty ja`, Ctrl-Q,
`.../try-ui bonsai en`. BOTH share `recording-v3/stores/household-synthetic`; opening missing
or invalid data never initializes/repairs/falls back. Enter now validates AND records;
Ctrl-R checks uncertain results/reloads, Ctrl-P cycles original history, Ctrl-E corrects,
Ctrl-N new, Ctrl-L ja/en, Ctrl-K currency from empty new form. Successful selection clears
amount/memo; uncertain result freezes editing/recording. Cold unexpected/prepared files show
read-only interruption, no implicit cleanup/retry. [Ignored trial README](../scratch/tui_comparison_review/README.md)
owns full controls/scales and optional explicit store selection. Next: human use of this
synthetic loop; later income/transfer, backup/restore/failure qualification before real data.
This does not authorize canonical store/UI adoption or operational recording.

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
Ctrl-Q quit. At this historical draft-only increment, candidate work disappeared at exit;
current launch uses the recording connection above. Human IME/keyboard feel remains unqualified.

## Completed bounded task — paired Notty / Bonsai_term draft TUI trial

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
| Explicit empty command records in outer decoders: retained | A source-field addition or repeated same-field maintenance produces actual drift | Review every profile's representable/unsupported families. A shared unadmitted command initializer is optional, not an admitted `Source.empty`; never silently empty new evidence or hide required per-adapter coverage review |
| Scoped input parsers: distinct roles retained | A concrete shared lexical mechanism has identical byte/error semantics, or an entrance genuinely has no consumers | Share only proven mechanisms, not acceptance/support meanings; inspect CLI, examples, type clients and oracle tests before removal. Fixture v2 is still consumed by comparisons, not obsolete merely because a native reader exists |
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
