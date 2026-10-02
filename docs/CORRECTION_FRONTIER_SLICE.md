# Supplied correction frontier — disjoint paths, not household authority

Status: implemented and locally tested. User authorized continued engine development;
this is a bounded engineering contract, not operational cutover or a new UI.

## Question and obligations

Can the supplied Event memory and raw correction list justify a unique frontier
under a disjoint-finite-path policy, while retaining every observation and edge?

- D: Event memory already enforces identity uniqueness. `Correction_check` resolves
  one edge but deliberately allows closed cycles, branches, and merges.
- P: semantic contract S1/S2/S4/S5/S6/S9/S10; exact opaque IDs and neutral Effects;
  original evidence and order are retained, not last-write-wins normalized.
- R: whole-list closure, unique targets/replacements, acyclicity, typed rejection,
  abstract qualified answer, independent graph oracle and negative client checks.

Narrow reference at `80e50c7c20ee35d9d22ec95ff5e6626e1286ab82`:
`Loam/Application/CorrectionFrontierSemantics.lean` (admission/frontier definitions)
and `CorrectionFrontierIndexed.lean` (lines 146–270, admitted projections/root-cut
neighbor). No source text copied, upstream writes, proof runs, or private data.
Reference proofs do not prove the independently handwritten OCaml implementation.

## Chosen contract

`Loam_application.Correction_frontier.create ~events ~corrections` accepts only:

1. Both endpoints of every edge resolve in the same supplied memory.
2. No target occurs twice, even with the same replacement (no deduplication/retry
   interpretation). One Event cannot have competing replacements.
3. No replacement occurs twice. Correction alone cannot settle multiple parents.
4. No directed cycle, including a self-edge, exists anywhere in the relation.

Together these justify disjoint finite paths, with untouched Events also retained
in the frontier. An intermediate node may be a replacement and a later target.
No Effect shape, Measure, date, Event kind, relation truth, or history completeness
is inferred. Event remains more general than validated ordinary Movement.

The abstract success retains original memory, raw corrections in supplied order,
and a materialized list of frontier Events: exactly original Events whose IDs
are not any correction target, in original Event order. Neither source is edited
or pruned. The output is conditional on supplied evidence and this policy; it is
not admitted current Actual, publication permission, or temporal history.

Empty corrections preserve all supplied Events; explicitly empty input is valid.
Missing/failed loading must never be silently substituted with these empty values.
There is no "best effort" frontier for invalid input.

## Refusal and deterministic order

Fail fast, not an exhaustive graph diagnostic:

- Scan raw edges in input order, using existing endpoint checks. First unresolved
  edge carries its one-based position and target-before-replacement missing errors.
- For a resolved edge, refuse repeated target before repeated replacement; report
  the original and repeated one-based positions and exact identity.
- Only after closure/uniqueness succeed, check cycles across all components in
  correction input order. Return an actual directed closed path (first ID repeated
  at the end); its rotation is diagnostic, not a semantic chronology.

Permuting inputs may change first-error choice/cycle rotation, not acceptance or
frontier membership. Permuting Event input changes representation order only.

## Mechanism and acceptance before implementation

Use existing Base persistent maps/sets, immutable accumulators, and tail-recursive
path walks. Build target/replacement indexes once, maintain completed nodes across
walks, discard these derived validation structures after answer construction.
No generic graph package, mutable cache, recursive non-tail chain descent, Clock,
framework, storage, CLI, or dependency addition is needed.

Acceptance: empty/untouched/disjoint/multi-hop paths; repeated equal/different
edges; missing endpoints/order; self/two-node/long/disconnected cycles; closed
branch and merge rejection; huge/zero/mixed Effects retained; exact opaque IDs;
permutation/replay; long-chain completion; abstract-answer forgery rejected.
An independent list/fuel graph oracle checks 10,000 deterministic generated cases
with seed `loam-correction-frontier-v1`, execution count asserted, and up to 10,000
shrink attempts. Keep existing normal/package/install/engine-only and CLI checks.

## Local qualification

macOS x86_64: nine new expect tests, 10,000 generated cases with asserted count,
all 512 directed graphs on three Events (bounded enumeration, not a universal
proof), and a 10,000-node chain in both edge orders plus its closing cycle.
Valid external client compiles using only Domain/Application interfaces; a closed
edge cannot be supplied as a frontier and a frontier record cannot be forged.
Normal/package-mode suites and install pass: 39 expect tests, 60,000 generated
cases across six seeds, three cram suites. Clean engine-only build leaves outer
CLI/presentation native libraries and CMIs unbuilt. Dependencies/lock unchanged.

Initial test compilation caught a reserved identifier and incorrect Quickcheck
combinator signatures. These were corrected using the installed interfaces; no
compiler policy was suppressed and no product semantics were weakened.

## Instrument review — recorded after implementation

This record was added when the user requested persistent tool-selection discipline;
not a claim that the new gate existed before this slice was implemented.

- Question/owner: conditional disjoint-path admission and frontier membership in
  `application/correction_frontier.*`, not operational currentness or root cuts.
- Evidence used: D/P/R task obligations, semantic/reference inspection, opaque
  interfaces, direct fixtures, independent list/fuel oracle, finite enumeration,
  generated cases, compiler-client checks. Actual results/bounds are above.
- DRAKON/D2 deferred: this operation's two validation phases and inward dependencies
  are inspectable in the small source/contracts. Revisit for branch-heavy ownership,
  publication/recovery, or multi-source authority/dependency paths.
- Alloy/Lean deferred for this implementation slice: finite OCaml graph checks
  directly exercise the current operation; no distinct new model/law was selected
  or executed. This leaves unrestricted correctness unproved. Review again at
  root/lineage exclusion (OPEN VR-01 in `HANDOFF.md`), not an indefinite deferral.
- Transition models not applicable yet: no retry, writer, clock, concurrency, or
  recovery transition exists here. Defining those operations reopens selection.
- Production reachability audit/latency benchmark deferred: clean engine-only
  build and explicit Dune dependencies cover the present boundary, not a general
  reachability/scale claim. Revisit for dependency growth or a named history workload.

The [instrument review gate](VERIFICATION.md#instrument-review-gate) applies before
future non-trivial work. No formal model-to-OCaml correspondence result exists for
this slice; upstream statements remain reference evidence only.

## Limits and next boundary

No root-to-terminal query, reflected-root cut, zero-origin assertion, current
quantity, Actual/Scheduled selection, occurrence/recording time, persistence, or
publication is implemented. A root-cut query must preserve whole correction
lineages; guessed timestamp-plus-deltas is not an equivalent shortcut. No claim
of formal correctness, measured large-history latency, or additional platforms.
