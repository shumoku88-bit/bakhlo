# Decision register

Status vocabulary:

- REQUIREMENT: explicitly requested by the user; see the charter.
- PROPOSED: recommended, not yet accepted as an implementation choice.
- OPEN: alternatives or scope still need a decision.
- IN PROGRESS: a bounded implementation step is underway; qualification may remain blocked.
- IMPLEMENTED / TESTED: engineering state with named evidence, not implicit user
  approval of every detail or a universal guarantee.
- ACCEPTED: record who/what authorized the choice and its evidence before use.
- SUPERSEDED: retain the reason and point to the replacement.

A bootstrap document is not approval of every recommendation it contains.

## Requirements

| ID | Requirement | Source |
| --- | --- | --- |
| R01 | OCaml implementation for long-term operation | User conversation |
| R02 | Extensibility, multiple UI forms, third-party maintenance | User conversation |
| R03 | Use formal methods in design/verification | User conversation |
| R04 | Portfolio intended for Jane Street-associated reviewers | User conversation |
| R05 | Repository memory for successor AI assistants | User conversation |
| R06 | Prepare for deterministic, typed, fast expert UI; no UI implementation/anticipatory dependencies in this phase | User instructions supersede earlier interactive-next-step proposal; no visual imitation or official standard claim |
| R07 | Continue with idiomatic functional OCaml and explicit effect boundaries, not scattered mutable procedural workflows | User's follow-up quality/style request; no claim of certification or official standards |
| R08 | Persist question-driven instrument selection and revisit triggers in this repository | User explicitly requested a mechanism so later pits do not forget the LOAM tools |
| R09 | High quality independent of adoption; target beyond household-accounting OSS through semantic rigor, reliability, and maintainability, not unused feature accumulation | User's explicit quality clarification; reuse LOAM research/evidence; competitive superiority is a target, not a qualified claim |
| R10 | Preserve previously investigated Core expressiveness, independently of current feature implementation | User explains LOAM verification supports most household/personal-accounting OSS functions; use exact prior evidence, not blanket parity/proof claims for OCaml |

## Decision status

Accepted initial scope and dependency rationale:
[ADR 0001](adr/0001-initial-scope-and-dependencies.md).
Implemented isolated development baseline:
[ADR 0002](adr/0002-isolated-development-baseline.md).
UI-independent application/read-model preparation:
[ADR 0003](adr/0003-ui-independent-application-boundary.md).

| ID | Status | Question / current recommendation | Evidence or approval needed |
| --- | --- | --- | --- |
| D01 | PROPOSED | Independent OCaml product; no Lean in production build/test/release | Confirm charter before implementation; document retained formal artifacts separately |
| D02 | PROPOSED | Modular monolith; domain independent of adapters | Validate with a small vertical slice and a second consumer |
| D03 | IMPLEMENTED baseline; matrix OPEN | Local OCaml 5.3.0 / Dune 3.24.2, pinned opam registry/lock | User authorized isolated setup; ADR 0002; tested macOS x86_64, Linux/Apple Silicon unqualified |
| D04 | ACCEPTED | Runtime Base + Zarith; test-only ppx_expect + Base_quickcheck; one capability reason per library | User approval; ADR 0001; exact baseline builds/tests locally (ADR 0002) |
| D05 | OPEN | Text or SQLite canonical storage | Write/recovery/backup/migration contracts; whole-system comparison, not benchmark alone |
| D06 | ACCEPTED (direction) | CLI first, first practical UI TUI; GUI/Web deferred until needed | User approval; ADR 0001; concrete toolkit remains open |
| D07 | ACCEPTED | Single user, local; no initial public access, multi-user, or sync | User approval; ADR 0001 |
| D08 | OPEN (dependency constrained) | No Async now; concurrency mechanics selected when needed | User approval of deferral; keep Domain independent |
| D09 | PROPOSED | Lean as optional reference; selected small formal models | Name each property and correspondence gap; do not maintain duplicate engines indefinitely |
| D10 | OPEN | Library/wire/storage compatibility policy | Identify real consumers and independently deployed clients before freezing contracts |
| D11 | ACCEPTED (development policy) | Synthetic data; existing LOAM stays authority; no dual writes | User approval; ADR 0001; actual migration/cutover/rollback still requires separate approval |
| D12 | Private hosting ACCEPTED; remainder OPEN | Working name, license, public release, source reuse | User authorized initial commit/private GitHub push; `shumoku88-bit/loam-ocaml` privacy rechecked; license/public release/reuse remain unresolved |
| D13 | PROPOSED | English technical entry docs, honest AI-assistance disclosure | Review for intended audience; do not imply endorsement or invent contributions |
| D14 | Movement/CLI locally TESTED | Exact Quantity, typed identities/Effects, validated ordinary Movement, pure CLI adapter and executable | User authorized next slice; [contract](MOVEMENT_SLICE.md); 13 domain/CLI expect tests, 20,000 generated cases, process/type cram checks; publication still absent |
| D15 | ACCEPTED current scope | Preparation only: no TUI/web/dashboard/components, toolkit adoption, OxCaml, or speculative UI state/cache | Latest explicit user instruction; [UI direction](UI_DIRECTION.md); previous workbench/interactive next step superseded |
| D16 | Locally TESTED | Typed existing Movement application command, abstract semantic preview, separate text projection | ADR 0003; 4 application expect tests, 10,000 replay cases, opaque-preview/client checks, clean engine-only build; CLI goldens preserved, dependency inventory unchanged |
| D17 | Locally TESTED | Functional-core review; retain strict sequencing and fatal warnings 8/9/11 across profiles | [Review and checks](ENGINEERING_STYLE.md); complete controls and 4 counterexamples per dev/release profile; normal/package tests and install pass; no business behavior/dependency change |
| D18 | Locally TESTED | Conditional zero-origin quantity projection over supplied Movements; explicit independent support and immutable coordinate index | User authorized continuing engine work; bounded engineering choice, not authority/cutover approval; [contract](BALANCE_SLICE.md); 6 expect tests, 10,000 original-Effect oracle cases, external-client/answer checks; no new external dependencies |
| D19 | Locally TESTED | Anonymous-Effect Event identity/memory and raw correction endpoint closure, not frontier admission | User authorized continuing quality-oriented engine work; [contract](CORRECTION_ENDPOINT_SLICE.md); 7 expect tests, 10,000 list-oracle cases, role/index/closed-answer compiler checks; no UI/storage/dependency addition |
| D20 | Locally TESTED | Disjoint-path frontier conditional on supplied Events/edges, not current Actual | User authorized next engine slice; [contract](CORRECTION_FRONTIER_SLICE.md); 9 expect tests, 10,000 graph-oracle cases, exhaustive three-Event graphs, long-chain/cycle and opaque-type checks; Base/Zarith budget unchanged |
| D21 | ACCEPTED (review policy) | Mandatory instrument review before non-trivial work; execution follows the question, not an all-tools pipeline | User's explicit repository-memory request; [gate](VERIFICATION.md#instrument-review-gate), AGENTS/contributor workflow, next composition review in HANDOFF; policy itself claims no tool execution |
| D22 | Root/cut/one-group quantity slices ACCEPTED / locally TESTED; later sequence PROPOSED | Evidence-led preservation: roots/lineage, root cuts, qualified quantity/admission, then separately earned operational boundaries/consumers | User accepted proceeding; [map](CORE_CORRESPONDENCE.md), [lineage contract](ROOT_LINEAGE_SLICE.md); VR-01–VR-04 complete within scopes; VR-05 Actual/support-family review OPEN; storage/UI/dependencies/cutover unchanged |
| D23 | Locally TESTED | Abstract root-to-terminal lineages materialized by existing disjoint-path admission, no second graph authority | 2 independent model + 9 lineage expect tests; four-node enumeration/model-code seam, 10,000 generated path cases, long-chain and external type checks; finite evidence, no unrestricted proof |
| D24 | Locally TESTED; optional specification laws CHECKED | Reflected-root cut binds independent unique/represented-root declarations to one qualified frontier, retaining all facts | User accepted proceeding; [contract](ROOT_CUT_SLICE.md); model/code 1,168 cases, 10,000 generated cases, snapshot/refusal/type seams; [three Lean specification laws](../formal/README.md), not graph proof or OCaml refinement; no product Lean dependency |
| D25 | Locally TESTED; optional specification laws CHECKED | One anonymous group's exact independent assertions plus unreflected terminal Effects; private arithmetic shared without merging support meanings | User accepted proceeding; [contract](CURRENT_QUANTITY_SLICE.md); 9 expect tests, 4,864 bounded seams and 10,000 generated source-list/Zarith cases; 3 new specification laws, no refinement/Actual/whole support-image claim; curated public namespace and external compiler checks |
| D26 | Locally TESTED; optional specification laws CHECKED | Anonymous groups with independent cuts, global coordinate ownership and explicit immutable re-observation against ONE supplied frontier | User requests continuing with qualified incremental commits; [contract](CURRENT_GROUPS_SLICE.md) recorded before code; model-only and 3 lookup laws before product changes; 256 construction/2,304 update seams, 10,000 generated cases and external type checks. Not Actual/support-family admission, persisted history or operational retry; no dependency/UI/storage addition |
| D27 | ACCEPTED practice; locally TESTED cleanup | Risk/invariant-based assurance, canonical document ownership and shared test-only fixtures/oracles | User requested applying the sustainability audit before the vertical slice; AGENTS/VERIFICATION/HANDOFF; existing evidence retained, no new tier machinery |
| D28 | Locally TESTED | Read-only synthetic base-validity/exact-assertion preview; not household Actual admission | `936da7f`; [interfaces](../application/actual_quantity_preview.mli), VERIFICATION; no canonical storage/authority/dependency decision |
| D29 | Ordinary source and two-family query locally TESTED | Distinct ordinary anonymous/base-validity Actual subset, then separated zero-origin/exact groups over one source | User accepted the bounded next sequence; VR-05B pre-code review in HANDOFF; [source](../application/actual_source.mli) / [query](../application/current_quantity_query.mli) contracts, VERIFICATION; v1 preserved and v2 read-only CLI checked. Broader metadata/routing/normalized admission remain OPEN |

## Recording a decision

For a consequential accepted choice, create a concise ADR under `docs/adr/`
when needed, using:

```text
Title / ID
Status and approval basis
Problem and requirements
Alternatives actually considered
Decision
Consequences, dependencies, and failure assumptions
Evidence and acceptance checks
Revisit trigger
```

Update this register to link the ADR. Do not pre-create empty ADR files for every
possible choice. A decision may be revised when new evidence earns a change.

## Stop conditions

- Do not select Async solely because of the intended portfolio audience.
- Do not select SQLite solely because professional applications often use it.
- Do not preserve text solely because the old implementation uses it.
- Do not pin the locally installed compiler as the project support policy.
- Do not add a Lean/Why3/Alloy/TLA+ toolchain without naming its distinct question.
- Do not start a public compatibility promise for hypothetical consumers.
