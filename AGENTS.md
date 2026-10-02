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
- Structural validation is not publication; preserve the validation-only preview
  label until actual write semantics exist. This phase is not visual imitation
  of Jane Street software or a claim of an official UI standard.

## Workflow

1. Name the observable behavior or evidence boundary being changed.
2. Separate deterministic repository facts (D), prior evidence (P), and residual
   questions (R). A few lines in a task note suffice; no mandatory tool ritual.
3. State assumptions and acceptance checks before implementation.
4. Implement the smallest end-to-end change.
5. Check adjacent correction, uncertainty, persistence, and projection boundaries
   where relevant; stop when no concrete seam remains.
6. Run the relevant checks and report their exact scope and failures.
7. Update the decision record and handoff if the result changes the next action.

Retain design reasons, not a transcript of every work session. Do not label
unrun tests as passing, proposals as decisions, or bounded checks as universal
proofs. If blocked, record the blocker rather than inventing a default.

## Command output

When installed, use `rtk git ...` / `rtk gh ...`, `rtk test <command>`, and
`rtk err <build-or-lint-command>` for long output. Use `sqz` only for other long
outputs, not stacked mechanically with `rtk`. Preserve raw evidence and exit
status when compression obscures compiler errors, mutations, or security issues.
Tool wrappers are local conveniences, not repository runtime dependencies.
