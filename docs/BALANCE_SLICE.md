# Conditional zero-origin Movement projection

Status: implemented and locally tested after the user's request to continue
engine development. This is an arithmetic/read-model slice, not an operational
current/historical balance service or a new storage/authority decision.

## Concrete question and scope

Given one explicitly supplied collection of structurally validated Movements and
independent zero-origin evidence for a `Locus × Measure` coordinate, what exact
quantity does that collection imply at that coordinate?

The answer is conditional on the supplied basis and the declared origin premise.
It does not admit that basis as current Actual, distinguish/select Actual from
Scheduled, resolve corrections, prove completeness, or choose a temporal cut.
Do not label it current household balance, purchasing power, or spendable today.
No dates, clocks, persistence, real-data adapter, CLI command, or UI is introduced.

## Obligations before implementation

- D: abstract Movement already enforces nonempty/nonzero, one Measure, exact
  conservation and preserved representation. Quantity is exact; identifiers retain
  exact spelling and have distinct Measure/Locus types.
- P: semantic contract S2/S3/S5/S6/S8/S9; upstream `ZeroOriginCoverage` and
  `BalanceReview` require explicit origin support independently of activity/view
  selection. `CurrentQuantityAnchor` needs correction-root cuts; a timestamp alone
  is not a substitute. Upstream findings are not proofs of this OCaml slice.
- R: coordinate-local support gate, immutable per-coordinate totals, structured
  unknown versus exact zero, construction/query separation, representation and
  multi-Measure checks, and an independent arithmetic oracle.

Reference checkout: `../loam`, observed commit
`180707c58647dc7cad3361458c1801be184d15af`. Only meanings were inspected; no source
was copied and no Lean or private-data command is needed for product checks.

## Minimal types and consumers

- `Effect_coordinate`: the actual neutral pair needed to ask/group the question.
  Public immutable fields retain distinct identifiers. Comparator order is exact
  lexicographic spelling for Map/Set mechanics, not chronology, priority, valuation,
  or a canonical ordering of household evidence. Its internal diagnostic S-expression
  exists for Base's comparator, not a UI/wire schema.
- `Zero_origin_coverage`: abstract explicit finite evidence set. Empty supports no
  coordinate. Reject the first repeated input coordinate with a one-based position;
  do not silently normalize factual evidence. Exact spelling remains distinct.
- `Zero_origin_projection`: immutable application model built once from coverage
  and supplied Movements. It indexes sums by coordinate, then answers typed queries
  with an abstract conditional answer or `Origin_unknown`. Never infer origin from
  activity, model membership, or lack of Effects.

Base Map/Set are existing approved capabilities with named consumers: indexed
projection/query and finite origin membership. No dependency is added. No generic
coverage ontology, command bus, cache/invalidation protocol, or placeholder session
is needed. The model is a disposable answer basis, not canonical evidence.

## Laws and boundary cases

1. No origin support means `Origin_unknown`, even with activity or zero net change.
2. Explicit support with no matching Effects yields exact zero **in the supplied
   scope**, not a claim about missing/unloaded canonical data.
3. Sum only matching Locus and Measure. Different Measures remain separate.
4. Include all matching Effects, including duplicates and same-Locus changes.
   Repeated Movements in input count repeatedly; no Event identity is inferred.
5. Positive/negative results and huge integers are exact; no clamp/valuation/rounding.
6. Reordering the supplied collection changes no numerical answer. Construction
   does not mutate/normalize the source Movements; presentation never builds facts.
7. Adding origin support changes answerability, not the already-defined delta sum.
8. Queries use the same immutable model; they neither rebuild totals nor read data.

## Acceptance and limits

- Small typed fixtures: unknown/known-zero distinction, activity without support,
  duplicate evidence rejection, split/repeated/same-Locus Effects, negative/huge
  values, and two Measures at one Locus.
- Generated direct Zarith oracle over original Effects, deterministic replay,
  reordered input, coverage locality, and asserted executed counts.
- External typed client needs Domain/Application only; conditional answer cannot
  be forged by ordinary well-typed code.
- Normal/package-mode tests, install, clean engine-only build; no CLI golden changes.

Local macOS x86_64 qualification passed: six new expect tests and 10,000 generated
cases (`loam-zero-origin-v1`, up to 10,000 shrink attempts, execution count asserted).
The complete suite has 23 expect tests, 40,000 generated cases, and three cram
suites. Package tests/install and a clean Domain/Application build pass; outer
presentation/CLI CMIs and libraries remain unbuilt by the engine-only targets.

Construction traverses represented Effects and uses immutable balanced maps;
queries perform coverage membership and one indexed lookup, not a history scan.
Exact arithmetic cost also depends on integer size. This is a complexity boundary,
not a measured large-history latency guarantee, correction/completeness proof,
formal verification, or operational cutover. A future Actual query must establish
its own admitted evidence/consistency scope before using arithmetic projections.
