# Instructions for the next pit

`pit` means an AI coding assistant. Read README, `docs/SEMANTIC_CONTRACT.md` and
`docs/HANDOFF.md`, then the relevant architecture/interfaces, verification and
references. Documentation describes scope; it does not authorize every future feature.

## Safety and authority

- Ordinary development/tests use synthetic inputs only. User explicitly approved a
  bounded read-only LOAM operational-data comparison; see HANDOFF's current task.
  Originals must not be written, recovered, migrated or synchronized. Keep private
  reads/copies/results in ignored scratch, never fixtures, commits or public output.
  Minimize payload exposure; Git rollback is not privacy/backup qualification.
  Existing LOAM remains sole authority; no dual writes or implicit cutover.
- Do not modify/build the sibling Lean repository or copy upstream source without
  separately resolving authorization/licensing. Consult only narrow reference owners.
- No new dependency, UI, canonical storage, migration, license/publication or push
  without the applicable decision. Local commits are authorized; release is not.
- Never turn missing/malformed/failed input into empty/zero/success. Preserve exact
  signed quantities, distinct Measures/Loci, Effect multiplicity, correction provenance,
  independently supplied support and unknown. Never trim identities or infer chronology.
- Domain Event is general; an ordinary source subset is not full evidence parity.
  Unsupported keys/metadata/families must refuse, never be erased by an adapter.
- Ordinary OCaml build/test/release stays Lean-free. Upstream/specification proofs
  do not automatically prove handwritten OCaml or household truth.

## Engineering and assurance

- Default to direct native OCaml implementation. Do not add Python bridges, generated
  OCaml payload pipelines or parallel test harnesses by habit. Additional tests/tools
  need a concrete unresolved risk; reuse earned OCaml checks rather than expanding
  scaffolding first. This does not permit weakening admission or erasing uncertainty.
- Immutable functional core, explicit effects; no dummy State, ornamental monads,
  generic bus, speculative cache/framework or anticipatory toolkit. Local mutation
  requires an owner/reason; test counters and honest shell I/O are legitimate.
- Keep inward dependencies and deliberate `.mli` abstractions. Never mix source
  generations or independent cuts. Share arithmetic mechanisms, not support meanings.
- Preserve strict sequencing and fatal warnings 8/9/11 in every profile. Handle closed
  semantic variants/fields explicitly; no warning suppression or catch-all evolution bypass.
- Before non-trivial work, record question, D/P evidence, residual gap, selected or
  deferred instruments, assumptions, checks and revisit trigger in a short task note.
  Follow `docs/VERIFICATION.md#instrument-review-gate`; not an all-tools pipeline.
- Reuse independent models/oracles. Consumers test connection/failure boundaries;
  do not add a model, theorem, 10,000-case campaign or long document by habit.
- Break unreleased prototypes freely when it improves the product. Delete unused
  routes, stale status documents and compatibility shims; retain meaningful guarantees,
  counterexamples and current decisions. Git owns historical implementation records.

## Workflow

1. Choose one observable semantic/failure boundary and inspect its nearest owners.
2. Record the bounded review before code; introduce only concrete consumed capabilities.
3. Implement, run relevant checks, review exact changes and qualify the increment.
4. Keep contracts in interfaces/architecture, evidence in VERIFICATION, next actions
   in HANDOFF. Link instead of duplicating inventories; no new ADR per slice/tool.
5. Stage intended checked files and commit before continuing. Report limits/failures
   honestly; commit does not authorize push, publication or operational adoption.

Use `./tools/bootstrap`, `./tools/opam`, `./tools/check`; no global environment changes.
Never commit `.tools/`, `.opam-root/`, `_opam/`, `_build/`, install output, scratch,
credentials or private logs. Scratch must remain excluded from Dune as well as Git.
For long output use `rtk git/gh`, `rtk test`, `rtk err`; `sqz` only otherwise, not stacked.
Preserve exact diagnostics/exit status when filters obscure failures or mutations.
