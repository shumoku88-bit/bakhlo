# Handoff — one-group conditional quantities; next is multi-group ownership review

Updated: 2026-10-02.

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
These remain conditional supplied-basis answers, not full multi-group support,
selected current Actual, chronology, completeness, or publication permission.

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

**VR-04 — OPEN; review before multi-group ownership/re-observation code.**

- Question: can independently observed groups keep different reflected cuts while
  exactly one live group owns each coordinate, over ONE supplied source scope?
- Prior evidence: `CurrentQuantityAnchor.lean` Evidence global coordinate uniqueness,
  `withoutCoordinates`/`replacingWithGroup?`, one-group cut/premise retention and
  source-list quantity oracle. Reuse exact findings; groups are anonymous factoring,
  not IDs or anchor-history graphs.
- Required seam: duplicate live coordinate refusal; same-source consistency owner;
  explicit re-observation of selected coordinates without altering unrelated
  assertions/cuts. Do not merge cuts into a common timestamp/baseline or select
  later groups by list position. Existing one-group values alone do not establish
  cross-group/source compatibility.
- Select one small contract and instruments before code. Existing row/delta laws
  do not prove ownership/routing or Actual selection; named model/code mapping and
  acceptance/revisit triggers are required. No dependency or broad support subsystem.
- Full Actual admission, zero-origin/opening/exact/known-present-unknown-amount support
  separation and operational balances remain separate. Independent assertions do
  not prove zero origin/history completeness; failed loading is never an empty basis.
- Publication/storage retry, crash and ownership transitions separately reopen
  TLA+/TLC, SPIN and fault injection. Unrestricted implementation claims require
  refinement evidence; no automatic installation, UI, migration or scope expansion.

## Implemented boundaries

- `Quantity`, typed Measure/Locus, neutral Effect, and validated ordinary Movement:
  exact quanta; Movement has narrower nonempty/nonzero/single-Measure/conservation
  rules. Structural success is not policy/world admission or recording.
- `Movement_check` / `Movement_text` / CLI shell: pure typed preview with positive
  total once, separate formatting; argv/streams/exit only at `bin/main.ml`.
  CLI still says **structurally valid (not recorded)**; goldens/exit semantics unchanged.
- `Effect_coordinate` / `Zero_origin_coverage` / `Zero_origin_projection`:
  independent finite support and indexed arithmetic over supplied Movements.
  Unknown is not zero; no current Actual/temporal completeness is inferred.
- `Identifier.Event`, `Event`, `Event_memory`: opaque exact caller-supplied IDs,
  retained anonymous neutral Effects, unique-ID immutable list/index. Empty/zero/
  mixed-Measure observations are valid here. Stable Effect keys/independent external
  fields are not represented; never drop them to fit this subset or claim full parity.
- `Event_correction` / `Correction_check`: raw edges, abstract endpoint closure
  with both observations, ordered missing roles. Closure is not graph admission.
- `Correction_frontier`: all endpoints present, unique targets/replacements,
  acyclic, with original sources and untargeted frontier Events in original order.
  Equal repeated edges, branches, merges, and cycles refuse; no latest-wins policy.
- Abstract lineages in that same module: each root has no incoming correction
  and maps to its exact reachable terminal with no outgoing correction. Untouched
  Events are singleton paths. Rows follow original **root order**, while frontier
  Events follow **terminal order**; these orders can differ. Root identity survives
  fresh tail extension, not arbitrary relation edits. Old immutable answers survive.
- `Reflected_root_cut`: abstract source-bound cut, independent unique represented
  roots only, exact terminal Events/remaining lineages materialized in root order.
  Getters do not revalidate/walk; source and original declaration order are retained.
  Old declarations require fresh construction on changed evidence. Not root kind,
  origin/quantity support, current Actual, or truth-of-reflection certification.
- `Current_quantity_projection`: one anonymous reconciliation group, one cut,
  unique independent exact assertions; duplicate coordinates refuse. Signed/zero/
  huge exact assertion + matching unreflected terminal Effect sum, with abstract
  components and indexed unknown/answer query. General Events remain neutral.
  Cut/assertion representation is retained; no multi-group ownership, other support-
  family routing, implicit now, correction-truth or full Actual claim.
- Private `Effect_sum` shares arithmetic with zero-origin, never support authority.
  Explicit public Application exports omit it. Logical module aliases preserve
  clean Dune dependency discovery; external cram includes the generated intermediary
  CMI. Never suppress missing-CMI warnings or rely on stale incremental artifacts.

All production Domain/Application records remain immutable; no business ref,
assignment, hidden I/O/process/time/randomness. Nine generated-test refs assert
actual case counts; finite model enumeration uses immutable folds. Strict sequence
and fatal warnings 8/9/11 remain active across dev/release profiles. Do not hide
semantic growth behind catch-alls/suppressions or invent a State/command bus.

## Qualification of the current implementation

macOS x86_64; isolated OCaml 5.3.0 / Dune 3.24.2:

- `./tools/check`, forced package-mode tests, and `dune build @install`: PASSED.
- Clean Domain/Application native build: PASSED; presentation/CLI native libraries
  and CMIs remained unbuilt. Tests remain private/release-enabled; no outward dependency.
- **68 expect tests**: Quantity 3, Movement 4, application 4, zero-origin 6,
  correction endpoints 7, frontier 9, lineage model 2, lineages 9, cut model 1,
  cuts 8, current quantity 9, CLI 6.
- **90,000 generated cases**: 10,000 each with `loam-quantity-v1`,
  `loam-movement-v1`, `loam-application-v1`, `loam-zero-origin-v1`,
  `loam-correction-endpoints-v1`, `loam-correction-frontier-v1`,
  `loam-root-lineage-v1`, `loam-reflected-root-cut-v1`, `loam-current-quantity-v1`;
  max 10,000 shrink attempts, execution counts asserted.
- Frontier three-node enumeration (512 graphs); root model/implementation four-node
  enumeration (65,536 simple graphs, 73 admissible sets), plus 1,168 cut declaration
  cases (304 admissible cuts), selected fresh-tail extensions, and 4,864 one-group
  graph/cut/assertion-support cases with original-Effect Zarith arithmetic. Bounded.
- New cases check root versus intermediate/terminal, exact huge/mixed/zero payloads,
  source retention, root versus terminal order, replay/permutation, fresh-tail
  extension and prefix re-rooting, plus 10,000-node chains in both edge orders.
- Three cram suites: actual CLI, external interface boundaries, and compiler-policy
  complete controls/counterexamples in dev/release. New lineage getters compile
  without outer CMIs; forged lineage/cut, closed-as-lineage/cut-source and
  cut-as-frontier, forged current group/answer, wrong cut source and private public-
  namespace aggregate access fail with expected diagnostics. Earlier boundaries remain.
- Optional Lean laws/check: PASSED with fatal warnings and no proof hole/custom
  axiom. Six laws: commutation/contribution noninterference `[propext]`,
  empty/composition/assertion translation `[propext, Quot.sound]`, unsupported `[]`;
  [pin/reproduction/gaps](../formal/README.md). Missing/
  relative/wrong-version/proof-hole controls refuse with expected status/diagnostic.
  Normal product tests passed with `LEAN` pointing to a nonexistent binary.
- Dependency/toolchain files unchanged; all 50 installed versions match the lock.
  Links/anchors/fences in 26 documents, source whitespace (cram blank-output
  indentation excepted), test inventory, and shell syntax checked.

Six optional selection/quantity specification laws were checked, not graph-to-row
or OCaml/Zarith refinement. These results do not establish full household admission,
whole current-support image/operational quantities, reflection truth, completeness,
durability/recovery, ergonomics,
latency/scale, migration, or wider platforms. Unsafe casts are outside interface
protection. Linux/Apple Silicon remain targets, not qualified environments.
CMI cram paths are internal Dune paths; update deliberately with toolchain changes.

## Repository and reference state

- User now requests incremental local commits after qualified semantic slices;
  AGENTS workflow records that policy. Root/cut/one-group quantity work is the
  first accumulated checkpoint to commit under it. Use live `git log`/status for
  checkpoint IDs and pending work rather than self-referential commit IDs here.
- Last confirmed pushed checkpoint is `623316a` (correction engine + D21), private
  `shumoku88-bit/loam-ocaml`, branch main. Later local commits are not thereby
  pushed or released. This request specifies commit cadence, not an additional
  push; report local/remote refs separately and do not claim unperformed pushes.
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

First VR-04: qualify multi-group coordinate ownership/re-observation and one-source
consistency without changing unrelated cuts/assertions. Then separately qualify
Actual/support-family selection before operational balance claims. One-group
quantities and correction cuts alone do not choose the full support/Actual image.
Do not force general Event evidence through ordinary Movement narrowing or infer
history/zero origin from activity. Failed/missing loading is never an empty basis.

Read `CORE_CORRESPONDENCE.md`; expand only a selected evidence row, not a whole
corpus/module backlog. Preserve earned expressiveness and independent evidence;
select later derived consumers only when used. Storage choice remains OPEN pending
write/retry/atomicity/durability/backup/restore/migration contracts. UI/public release/
real-data cutover remain separately scoped; no automatic toolkit/cache/framework
or timestamp-based balance simplification follows from this slice.
