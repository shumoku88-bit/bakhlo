# Instructions for the next pit

`pit` means an AI coding assistant, not a particular model. This repository is
project memory for an OCaml product, not permission to implement every proposal.

## Required reading

Before substantive design or implementation, read in order:

1. `docs/CHARTER.md`
2. `docs/SEMANTIC_CONTRACT.md`
3. `docs/DECISIONS.md`
4. `docs/HANDOFF.md`

Then read `docs/ARCHITECTURE.md` and `docs/VERIFICATION.md` for the relevant work.
Before non-trivial work, apply the **Instrument review gate** in
`docs/VERIFICATION.md`; record the question, evidence gap, tool choice or deferral,
and revisit trigger in the slice contract/task note. OCaml types/tests do not
license silently forgetting the LOAM design/verification instruments.
For environment/dependency changes, read `docs/DEVELOPMENT.md` and ADR 0002.
Use `./tools/bootstrap` and `./tools/check` rather than global opam/dune. Never
commit `.tools/`, `.opam-root/`, `_opam/`, `_build/`, or generated install files.
Keep synthetic package experiments in excluded `scratch/`; Git ignore alone
is not a Dune discovery boundary.
Use `docs/REFERENCES.md` for narrow upstream evidence; do not explore the entire
parent workspace or private data to rediscover already-indexed decisions.

## Authority of statements

- Explicit user requirements are recorded in the charter.
- Architecture and implementation choices labeled PROPOSED are not accepted.
- An open decision must not silently become an implementation default.
- Tests and proofs establish only the statements and scopes they actually check.
- This repository does not currently own operational household data.
- Ask before changing product scope, introducing a material dependency or
  persistence decision, copying upstream code, or switching data authority.

## Non-negotiable safety boundaries

- Do not read, copy, mutate, migrate, or commit real household data as part of
  bootstrap, tests, demos, or benchmarks. Request explicit authorization for any
  later scoped migration. Use synthetic fixtures by default.
- Do not write to the sibling Lean repository as part of ordinary work here.
- Never run both implementations as independent production writers. A comparison
  executable or isolated test copy is not a second operational authority.
- Never substitute zero/empty/success for absent or malformed evidence.
- Never claim that a Lean theorem proves hand-written OCaml code correct.
- Do not add a Lean dependency to production build/test/release.
- Do not create a remote, publish, choose a license, or copy upstream code without
  resolving the applicable authorization/provenance question.

## Engineering discipline

- The quality target is independent of adoption/popularity: high semantic rigor,
  operational reliability, and maintainability within the retained scope. A small
  feature set is not a lower assurance target. Deliberately unused features need
  not be added; required but unqualified behavior must still be identified.
  Consult LOAM's prior research/verification before rediscovering design answers.
  Read `docs/CORE_CORRESPONDENCE.md` before selecting a preservation/extension slice.
  Preserve earned Core expressiveness, not just the currently implemented OCaml
  operations. A missing derived feature is not evidence of an inadequate Core;
  do not mistake the present anonymous-Effect subset for full evidence parity.
  Do not claim superiority to other OSS without a scoped, evidenced comparison.
- Use a small modular monolith unless concrete requirements justify otherwise.
- Keep domain semantics independent of UI, storage libraries, transports, clocks,
  and asynchronous runtimes.
- Use explicit `.mli` contracts, abstract types, exhaustive variants, and exact
  arithmetic where they protect a named invariant.
- Every added direct library needs a concrete capability reason and a named
  consumer, not merely convenience. Record scope, alternatives, transitive cost,
  and removal/revisit conditions. Initial budget: runtime Base + Zarith;
  test-only ppx_expect + Base_quickcheck. No Core, Async, or storage dependency
  without a new justified decision. See `docs/adr/0001-initial-scope-and-dependencies.md`.
- Prefer immutable data and pure functions for the functional core; keep I/O at
  explicit edges. Local mutation needs a named owner and concrete justification,
  not scattered business-state updates or a dogmatic ban on loops/refs.
- Keep strict sequencing and fatal warnings 8/9/11 in every build profile. Do not
  hide a new semantic constructor/field behind a catch-all or warning suppression;
  use deliberate handling. See `docs/ENGINEERING_STYLE.md` and compiler specimens.
- Advanced types, functors, and Jane Street libraries must earn their place.
  Neither avoid them for appearance nor add them for portfolio signaling.
- Share mechanisms without collapsing independent meanings.
- Avoid generic plugin frameworks, universal event buses, speculative backend
  matrices, and permanent compatibility layers without a current requirement.
- Do not create placeholder APIs or unimplemented UI navigation merely to make
  the repository look complete.
- Current phase is preparation for a future UI, not UI implementation. Read
  `docs/UI_DIRECTION.md` and ADR 0003. Do not build a TUI, web UI, dashboard,
  visual components, or speculative interaction/navigation/load state models.
- Do not add Bonsai, Bonsai_term, Notty, Lwd, React, web frameworks, or OxCaml
  for anticipated UI needs. Keep the existing dependency budget; no branding
  or dependency theatre. A future toolkit must remain replaceable.
- Domain/application never depend on terminal/key/widget/screen/layout state,
  CLI formatting, or UI-specific JSON. Clients depend inward; semantic answers
  precede presentation. Actual commands take explicit values and return typed
  results; no universal command/view-model framework.
- Time and effects are explicit when a real operation needs them. No hidden now,
  filesystem, process, environment, randomness, or speculative Clock/cache.
  Preserve distinct meanings; introduce state variants only for existing states.
- Read `docs/BALANCE_SLICE.md` before quantity/read-model work. The zero-origin
  projection is conditional on supplied Movements and independent declared
  coverage; never relabel it current Actual, historical completeness, purchasing
  power, or spendable today. Current anchors need qualified correction-root cuts,
  not guessed timestamps. Failed/missing data loading must never become an empty
  projection basis. Indexed totals are disposable, not canonical evidence.
- Before Event/correction work read `docs/CORRECTION_ENDPOINT_SLICE.md`. General
  anonymous-Effect Events are not ordinary Movements. Identity-unique memory and
  endpoint closure do not establish current Actual/frontier authority. Never use
  source list order, self/cyclic/competing closed edges, or guessed dates to select
  current evidence; retain both observations and the explicit correction fact.
  Do not import keyed Effects/independent metadata by silently dropping them.
  `docs/CORRECTION_FRONTIER_SLICE.md` now qualifies disjoint paths only within a
  supplied memory/relation: closure, unique targets/replacements, acyclicity.
  Retain original facts; its derived frontier is not an Actual image, root-cut
  witness, history-completeness assertion, or publication authorization.
  `docs/ROOT_LINEAGE_SLICE.md` now qualifies root-to-terminal associations within
  that relation, in original root order. Stability is under fresh tail extension,
  not prefix insertion/removal/scope changes. `docs/ROOT_CUT_SLICE.md` now qualifies
  reflected-root exclusions bound to one immutable supplied frontier; duplicate,
  unknown and non-root declarations refuse. Source facts remain retained.
  `docs/CURRENT_QUANTITY_SLICE.md` now qualifies one anonymous assertion group's
  conditional exact quantities and decomposition over that cut. No assertion means
  unsupported, not zero; this is not multi-group ownership or admitted Actual.
  `docs/CURRENT_GROUPS_SLICE.md` qualifies multi-group ownership/re-observation over
  ONE supplied source, not full Actual/support-family admission. Resolve OPEN VR-05
  in `docs/HANDOFF.md` before that broader composition.
  Never merge independently observed cuts, infer current support from activity,
  or use the private Effect_sum as a public support API. Its public Application
  namespace is explicitly curated; update exports/CMI specimens with new operations.
  Optional specification laws do not prove graph/OCaml refinement, and their checks
  must never become ordinary product build/test/release dependencies.
- Structural validation is not publication; preserve the validation-only preview
  label until actual write semantics exist. This phase is not visual imitation
  of Jane Street software or a claim of an official UI standard.

## Workflow

1. Name the observable behavior or evidence boundary being changed.
2. Separate deterministic repository facts (D), prior evidence (P), and residual
   questions (R). A few lines in a task note suffice; no mandatory tool ritual.
3. Apply the instrument review gate; use the smallest set answering distinct
   residual questions. Record why a relevant instrument is used/deferred, not a
   blanket "the compiler/tests are enough". No mandatory all-tools pipeline.
4. State assumptions and acceptance checks before implementation. Scale evidence
   by semantic/failure risk, not directory or a per-slice checklist. Reuse independent
   models/oracles; add a model, theorem or compiler specimen only for a new gap.
5. Prefer a small vertical input-to-answer change. Shared test helpers live outside
   test-case modules; never share production algorithms into the expected-value oracle.
   Keep current evidence in VERIFICATION, next actions in HANDOFF, and stable contracts
   in interfaces/architecture; link instead of copying status lists into many documents.
6. Check adjacent correction, uncertainty, persistence, and projection boundaries
   where relevant; stop when no concrete seam remains.
7. Run the selected checks; report actual results, model/code correspondence,
   scope and failures. Selected/planned is not executed/qualified.
8. Update the decision record and handoff, including deferred-tool revisit
   triggers, if the result changes the next action.
9. The user requests incremental local commits: after a qualified semantic slice,
   review/stage only intended source/tests/docs and commit before the next slice.
   Do not leave multiple completed slices accumulating as an unexplained dirty
   tree. Commit is not push/public release; report local/remote state separately.

Retain design reasons, not a transcript of every work session. Do not label
unrun tests as passing, proposals as decisions, or bounded checks as universal
proofs. If blocked, record the blocker rather than inventing a default.

## Command output

When installed, use `rtk git ...` / `rtk gh ...`, `rtk test <command>`, and
`rtk err <build-or-lint-command>` for long output. Use `sqz` only for other long
outputs, not stacked mechanically with `rtk`. Preserve raw evidence and exit
status when compression obscures compiler errors, mutations, or security issues.
Tool wrappers are local conveniences, not repository runtime dependencies.
