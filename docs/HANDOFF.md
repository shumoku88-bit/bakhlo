# Handoff — synthetic Actual quantity preview; broader admission still open

Updated: 2026-10-03.

## Intent, scope, and current stop point

The user wants a high-quality long-lived OCaml household engine independent of
adoption/popularity, aspiring beyond household/personal-accounting OSS in retained
semantics, reliability, and maintainability. This is a target, not certification,
a demonstrated product comparison, or affiliation with Jane Street.

The user stresses that LOAM research/verification has already established Core
expressive sufficiency for most such functionality, including intentionally unused
features. Preserve earned distinctions and exact prior evidence rather than
rediscovering a CRUD ontology. Missing OCaml operations do not imply an inadequate
upstream Core; upstream proofs also do not automatically prove new OCaml code.
Distinguish intentional exclusions, planned capabilities, and required but
unqualified behavior. See `CORE_CORRESPONDENCE.md` and charter requirements 11/R10.

Accepted scope remains: local single user, macOS/Linux targets, CLI first, eventual
TUI; no current UI implementation, public access, multi-user, or synchronization.
Runtime Base + Zarith; tests ppx_expect + Base_quickcheck. No new dependency, clock,
mutable business state, cache/framework, storage, or operational data access.
Existing LOAM remains sole household authority; no dual writes or implicit cutover.
Public publication/license/source copying/migration still need separate decisions.

Qualified engine boundaries now reach one-source groups and a read-only synthetic
base-validity/exact-support CLI preview. Stable contracts belong to architecture/
interfaces; evidence to VERIFICATION. No full Actual/support-family admission,
history completeness, operational balance or publication permission follows.

## Instrument review and the next trigger

D21 requires [instrument review](VERIFICATION.md#instrument-review-gate) before
non-trivial work. AGENTS/contributor workflow link it. Select instruments by
residual question, record relevant use/deferral reasons and revisit conditions;
never silently replace the LOAM instruments with compiler/test success. No
all-tools pipeline, installation authority, or mandatory Lean production build.

**VR-01–VR-04 COMPLETE only within their recorded scopes:**
[root lineages](ROOT_LINEAGE_SLICE.md), [reflected cuts](ROOT_CUT_SLICE.md),
[one-group quantities](CURRENT_QUANTITY_SLICE.md),
[one-source ownership/re-observation](CURRENT_GROUPS_SLICE.md).
Current evidence/bounds are in VERIFICATION; historical reviews stay in those records.
No optional law proves graph admission, grouping indexes or OCaml refinement.

**VR-05 — bounded vertical preview qualified; broader admission OPEN.**

- Question: what qualified supplied source and independent support premises permit
  Actual-only conditional queries, while separating zero-origin, opening, exact
  current assertions and known-present/unknown-amount? Do not infer Event kind
  from Effects or convert a failed/missing loader into an empty source.
- Prior evidence: correspondence/reference owners (CurrentBalanceReview,
  BalanceReview, ActualDate and admission), tested one-source groups/cuts and
  zero-origin arithmetic. Preserve unused Core expressiveness and independent
  metadata; the current anonymous Event subset is NOT full evidence parity.
- Inspected `../loam` at `dca1aac7`: ActualValidity, ActualEvidence,
  NormalizedActualAdmission, ActualDate, CurrentBalanceReview/CurrentSupportRouting.
  Actual is separate validity, not an Event kind flag. First preview admits one
  base ISO date per retained Event (unique/closed/complete), frontier and exact groups.
  Use existing oracles plus focused date/reference/error and real CLI/file fixtures;
  no new model/theorem: the residual gap is boundary composition. Revisit models on
  validity-history or support-routing changes; transition tools on writes/recovery.
- Input is ONLY versioned synthetic `LOAM-OCAML-ACTUAL-FIXTURE` blocks (EVENT/date,
  EFFECT, END-EVENT; CORRECTION; GROUP/REFLECT/ASSERT/END-GROUP; final END/newline).
  Other versions/rows/metadata/keyed Effects/support families refuse, never drop.
  This is base-validity/exact-support preview, NOT full normalized Actual admission
  (balance, Exchange/Reversal, description etc.), historical reconstruction or authority.
  Acceptance: malformed/truncated/missing files fail closed; dates never select winners;
  source/independent cuts survive; unknown never zero; existing movement CLI unchanged.
  Contract details live in interfaces and synthetic examples, not another slice document.
- Execution: focused boundary tests, real CLI/file and public type specimens passed;
  normal/package/install and clean engine-only builds passed. Existing evidence retained;
  tools/lock/dependencies unchanged. See VERIFICATION; optional artifact unchanged/not rerun.
- No automatically accepted feature/dependency/storage choice follows. Revisit
  DRAKON for fallback/routing order, D2 for source/authority growth; transition
  models/fault injection for concrete retry/crash/publication contracts, not an
  imaginary concurrent workflow. Operational balances require separate qualification.

**VR-05B — ordinary source qualified; two-family query SELECTED before code.**

- D/P: upstream observed `6e8015c3`; admission/routing/date owners unchanged against
  `dca1aac7`. Existing validity, frontier/cut/groups and source-list/Zarith oracles.
- R: qualify ALL retained Effects as nonzero and per-Measure balanced (including
  superseded Events); empty and balanced mixed-Measure Events remain allowed.
  Share base validity admission, not Movement narrowing; legacy preview stays general.
- Then one supplied source + unique zero-origin declarations + exact groups; reject
  family overlap globally, even equal amounts. Zero-origin sums the ordinary terminal
  frontier, anchors retain their own cuts. No activity/date-derived support or winners.
- Use focused physical/reference/type/real-CLI tests and a small two-coordinate
  support/cut enumeration with existing list/arithmetic oracle; no new model/theorem.
  Explicit guards suffice for DRAKON, unchanged inward topology for D2; reconsider
  finite/formal models on validity-history/new routing laws, fault tools on writes.
- Scope: ONLY anonymous ordinary/base-validity Actual, not full normalized admission;
  keys, metadata, validity revisions, Exchange/Reversal/opening/presence still refuse.
  New synthetic v2/read command; preserve v1, no canonical format/dependency/data change.
  Acceptance: rejected source never queried; separate cuts/support; exact/unknown/zero;
  whole input refusals and unchanged read-only fixtures.
- Source execution: normal/package/install and clean engine-only checks passed;
  predicate/refusal/retention/public-client specimens passed (VERIFICATION). Legacy
  preview/date behavior retained. Two-family query is the next increment, not yet run.

## Stable contracts and evidence

Use [architecture](ARCHITECTURE.md) and public interfaces for implemented boundaries;
[verification](VERIFICATION.md) owns current evidence, bounds and platform limits.
Slice documents retain historical qualification; do not duplicate their inventories here.

## Repository and reference state

- User now requests incremental local commits after qualified semantic slices;
  AGENTS workflow records that policy. `fb38f38` commits multi-group work;
  `18276e4` commits risk-based assurance/helper cleanup. Use live `git log`/status
  for this vertical checkpoint, not a self-referential commit ID here.
- Live remote `main` was read via `git ls-remote` on 2026-10-03: `8974041`
  (root/cut/one-group quantity checkpoint) already exists there; private status
  rechecked via GitHub metadata. This supersedes the older `623316a` observation.
  Multi-group/cleanup/vertical work issues no push; checkpoints remain LOCAL. Commit cadence
  does not itself authorize another push/release; report local/remote refs separately.
- Reference revisions/owners are recorded in REFERENCES (latest narrow VR-05
  inspection `dca1aac7`, not whole-checkout equivalence). No upstream writes/build/
  proof runs, source copying or private-data access. Optional local Lean is independent,
  imports only Std and is never a product dependency.
- Use `./tools/bootstrap`, `./tools/opam`, `./tools/check`; no global configuration.
  Opam 2.6.0, registry `ac27950e5eac6c981ad809dff370c937820b7893`, exact lock.
  Earlier fresh-switch replay is prior evidence, not rerun for this dependency-
  unchanged slice. OS compiler/GMP prerequisites are not hermetically pinned.
- Never commit local environments, build/install output, scratch, or private logs.
  Scratch is excluded from Dune as well as Git. `-p` already selects a root: do not
  combine it with `--root`. Qualify Base/Domain namespaces; lowercase `effect` is reserved.

## Next bounded work and stops

User approved risk-based assurance and a synthetic-input → loader → Actual →
quantity → read-only CLI vertical slice, with small qualified commits.
Cleanup complete: shared fixture/source-list oracle modules replace cross-test
helper dependencies; duplicated README/HANDOFF inventories link to VERIFICATION.
Cleanup committed separately; no tests/models/laws removed. First vertical preview
is qualified only for the reviewed base-validity/exact-support subset. Next choose a
concrete missing evidence family/consumer, then review its boundary before code;
ordinary source is now qualified; two-family query is next. Full validity history,
normalized admission and wider separated support routing remain OPEN.
Do not expand a synthetic fixture grammar into canonical storage by accident.
Do not force general Event evidence through ordinary Movement narrowing or infer
history/zero origin from activity. Failed/missing loading is never an empty basis.

Read `CORE_CORRESPONDENCE.md`; expand only a selected evidence row, not a whole
corpus/module backlog. Preserve earned expressiveness and independent evidence;
select later derived consumers only when used. Storage choice remains OPEN pending
write/retry/atomicity/durability/backup/restore/migration contracts. UI/public release/
real-data cutover remain separately scoped; no automatic toolkit/cache/framework
or timestamp-based balance simplification follows from this slice.
