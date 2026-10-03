# Handoff — one-source multi-group quantities; next is Actual/support-family review

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

The user accepted proceeding through root/terminal and reflected-root exclusion.
`Correction_frontier` materializes abstract lineages after its existing admission;
`Reflected_root_cut` consumes that qualified source plus independent reflected IDs,
refusing duplicate/absent/non-root declarations and retaining all source facts.
No second graph authority, source pruning, guessed Event, or implicit rebinding.
`Current_quantity_projection` now adds one anonymous group's independent exact
coordinate assertions plus unreflected terminal Effects. It retains source/premises
and exact assertion/delta/total components, with typed unsupported queries.
`Current_quantity_groups` now composes multiple anonymous declarations against ONE
supplied frontier, preserving independent cuts and rejecting shared coordinate
ownership. Explicit immutable re-observation replaces selected premises only.
These remain conditional supplied-basis answers, not full admitted support-family
routing, selected current Actual, chronology, completeness or publication permission.

## Instrument review and the next trigger

D21 requires [instrument review](VERIFICATION.md#instrument-review-gate) before
non-trivial work. AGENTS/contributor workflow link it. Select instruments by
residual question, record relevant use/deferral reasons and revisit conditions;
never silently replace the LOAM instruments with compiler/test success. No
all-tools pipeline, installation authority, or mandatory Lean production build.

**VR-01 root/terminal selection and scoped implementation checks: COMPLETE.**
Read `ROOT_LINEAGE_SLICE.md`: source/evidence inspection plus an independent finite
integer-relation transitive-closure model was selected before implementation.
Model-only enumeration ran before engine changes; it neither imports production
IDs/indexes nor uses successor walks. All 65,536 four-node simple graphs were then
compared at the model/code seam; all 73 admissible association sets agree. This is
bounded executable evidence, not a universal proof or an Alloy/Lean run. Missing
endpoints/parallel repeats are outside enumeration and have separate specimens.

**VR-02 reflected-root selection and scoped cut checks: COMPLETE.**
Read `ROOT_CUT_SLICE.md`: group/root-membership guards were inspected, a list-cut
specification reused the independent closure model, and one model test explored
1,168 relation/represented-subset cases before product changes. Actual admission,
ordered refusals and selected terminals then matched all cases (304 admissible).
Fresh-tail seams exclude the new terminal; prefix/absent-root rebinding refuses.
Optional Lean 4.33.1 proved three generic row-selection laws before product changes,
not graph correctness or OCaml refinement. Production checks remain Lean-free.

**VR-03 one-group quantity selection and scoped checks: COMPLETE.**
Read `CURRENT_QUANTITY_SLICE.md`: current-anchor/group and support-routing owners
were inspected before choosing one supplied anonymous group. Three optional signed-
Int laws were checked before product changes, not OCaml/Zarith refinement. All
4,864 finite graph/cut/support cases and 10,000 generated source-list/Zarith cases
match exact decomposition/unsupported answers. Shared private arithmetic preserves
zero-origin/CLI semantics; no assertion/current support is inferred from activity.

**VR-04 one-source multi-group ownership/re-observation: COMPLETE within scope.**
Read `CURRENT_GROUPS_SLICE.md`: contract/tool selection preceded code. Independent
integer/list model explored 256 ownership/cut cases (144 admitted), 2,304 valid
updates/replays before product changes. Three optional Lean whole-premise lookup
laws ran before implementation. Model/code seams and 10,000 generated source-list/
closure/original-Effect Zarith cases then passed. All groups qualify against ONE
explicit frontier; different cuts survive. Root/local/global checks have explicit
order; re-observation qualifies incoming BEFORE removing old assertions. It never
mixes separately bound projections, chooses a list-order winner or allocates group IDs.
DRAKON deferral was revisited with explicit procedure/refusal order; topology stays
one-source/pure. Artifact laws do not formally refine grouping/ownership indexes.

**VR-05 — OPEN before full Actual/support-family admission code.**

- Question: what qualified supplied source and independent support premises permit
  Actual-only conditional queries, while separating zero-origin, opening, exact
  current assertions and known-present/unknown-amount? Do not infer Event kind
  from Effects or convert a failed/missing loader into an empty source.
- Prior evidence: correspondence/reference owners (CurrentBalanceReview,
  BalanceReview, ActualDate and admission), tested one-source groups/cuts and
  zero-origin arithmetic. Preserve unused Core expressiveness and independent
  metadata; the current anonymous Event subset is NOT full evidence parity.
- Required review: inspect exact kind/selection/support owners, decide one bounded
  contract and its representation/authorization gaps, select instruments and model-
  code seams BEFORE coding. Source-bound groups alone do not qualify current Actual,
  completeness, reflection truth or routing across independent support families.
- No automatically accepted feature/dependency/storage choice follows. Revisit
  DRAKON for fallback/routing order, D2 for source/authority growth; transition
  models/fault injection for concrete retry/crash/publication contracts, not an
  imaginary concurrent workflow. Operational balances require separate qualification.

## Stable contracts and evidence

Use [architecture](ARCHITECTURE.md) and public interfaces for implemented boundaries;
[verification](VERIFICATION.md) owns current evidence, bounds and platform limits.
Slice documents retain historical qualification; do not duplicate their inventories here.

## Repository and reference state

- User now requests incremental local commits after qualified semantic slices;
  AGENTS workflow records that policy. `8974041` commits root/cut/one-group quantity
  work. The multi-group slice is the next qualified local checkpoint; use live
  `git log`/status for its ID/pending work, not a self-referential commit ID here.
- Live remote `main` was read via `git ls-remote` on 2026-10-03: `8974041`
  (root/cut/one-group quantity checkpoint) already exists there; private status
  rechecked via GitHub metadata. This supersedes the older `623316a` observation.
  The multi-group slice issues no push and remains a LOCAL checkpoint. Commit cadence
  does not itself authorize another push/release; report local/remote refs separately.
- Local reference observed `4d7a29a5`; upstream root/frontier/current-anchor files
  inspected are unchanged against earlier `80e50c7c`. No upstream write/build/
  proof run, source-text copy, or private-data access. The new optional local Lean
  artifact imports only Std and uses an already installed native binary, not
  upstream code or its build. See `REFERENCES.md`.
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
Existing normal/package/install checks passed unchanged; no tests/models/laws removed.
Revisit extraction only if the underlying semantics change.
First VR-05: review the bounded Actual/support contract before vertical code. Existing conditional
quantities/cuts/ownership alone do not choose the full support/Actual image or
justify operational balance claims.
Do not force general Event evidence through ordinary Movement narrowing or infer
history/zero origin from activity. Failed/missing loading is never an empty basis.

Read `CORE_CORRESPONDENCE.md`; expand only a selected evidence row, not a whole
corpus/module backlog. Preserve earned expressiveness and independent evidence;
select later derived consumers only when used. Storage choice remains OPEN pending
write/retry/atomicity/durability/backup/restore/migration contracts. UI/public release/
real-data cutover remain separately scoped; no automatic toolkit/cache/framework
or timestamp-based balance simplification follows from this slice.
