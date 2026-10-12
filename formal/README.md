# Optional semantic design experiments

This is development evidence, **not a product build/test/release dependency**.
No upstream source is imported, no Lake project or OCaml binding is involved,
and no second operational engine exists. `tools/check` invokes neither experiment.

## Canonical reference retention (Alloy)

`CanonicalReferenceRetention.als` asks whether a corrected current row and direct
source-posting retention are sufficient at the existing whole-row admission boundary.
It is an original, bounded structural slice, not a new canonical schema or a full
Actual/Relation admission model. Version atoms do not mandate durable version IDs.

The current [canonical-data research](../docs/CANONICAL_DATA_DESIGN.ja.md) owns the
mapping, seven expected SAT/UNSAT outcomes, concrete witnesses and remaining gaps.
`test/canonical_reference_tests.ml` now probes the full-row premise with existing native
owners: relation-local admission cannot distinguish balanced/unbalanced rows with the same
referenced posting, whereas whole-source admission refuses the latter. It also covers
aggregate bounds, retained refund endpoints and root/basis double counting. These tests do
not prove candidate C's combined admission or replace the bounded model's stated assumptions.
The research's LOAM asset reuse table is the first entrance for already-earned semantics
(e.g. Observation 246 and current reversal/relation owners). These local probes are not new
LOAM findings. Add a formal question only for a named representation/conversion residual;
do not duplicate existing laws or confuse historical admission with current writer permission.
Alloy 6.2.0/SAT4J was executed using the already-installed launcher and JDK, with no
installation or sibling-repository execution/source copy. Start a fresh output path:

```sh
umask 077
run=$(mktemp -d "$PWD/scratch/canonical-alloy-XXXXXX")
alloy exec -c '*' -s sat4j -n -t json -o "$run/solutions" \
  formal/CanonicalReferenceRetention.als
```

Run from the Bakhlo root, only with an existing Alloy command. Do not use `-f` to
overwrite evidence. CLI success alone is not successful model qualification:
inspect every named command in `receipt.json`; a SAT `check` is a counterexample.
`tools/check` does not invoke Alloy. An unavailable environment remains a limit;
there is no automatic download or mandatory model CI.

## Root-cut laws (Lean): question and statements

`RootCutLaws.lean` defines exclusion of supplied `(root, terminal)` rows by a
Boolean root predicate. It proves for arbitrary finite rows:

- `exclusion_commutes_with_terminal_update`: any transformation of terminal values
  leaving roots intact commutes with exclusion;
- `empty_cut`: the everywhere-false predicate preserves every row and its order;
- `composition`: successive exclusions equal exclusion by predicate union.

The later one-group quantity slice adds three general signed-Int laws:

- `absent_assertion_stays_unsupported`: any delta leaves an absent assertion unsupported;
- `assertion_translation`: translating an exact assertion translates the answer equally;
- `reflected_contribution_noninterference`: changed reflected terminal contributions
  cannot change the delta, with roots fixed and unreflected contributions equal.

The multi-group slice adds three lookup-level whole-premise ownership laws:

- `incoming_premise_wins`: a supplied replacement wins at its explicit coordinate;
- `unrelated_premise_preserved`: absent incoming support leaves the ENTIRE old premise
  unchanged (assertion and cut, not merely amount);
- `reobservation_lookup_idempotent`: repeating the same replacement preserves lookups.

Premise is an arbitrary type; instantiate with assertion/cut pairs. These laws do
not prove group-list representation, admission, source truth or ownership indexes,
and lookup idempotence is not durable publisher retry behavior.

This retains selection and answerability laws behind fresh-tail correction stability.
It does **not** prove that arbitrary graph edits preserve roots, that supplied rows
are graph-correct, that cut declarations are admissible, or that OCaml refines this
specification. Prefix insertion can change a root. Truth of reflection/assertion
premises, full Actual selection, chronology, completeness, storage/loading and process
failures are outside these statements.

## Reproduce without automatic installation

Qualified locally with installed Lean **4.33.1**, release commit
`819816b2e0a3bf405af45ae5c7af2491d8f5bee6`, macOS x86_64. Point `LEAN` at an
existing native binary of that version, not a manager that downloads a default:

```sh
LEAN=/absolute/path/to/lean-4.33.1/bin/lean ./tools/check-root-cut-laws
```

The optional script rejects a missing/non-absolute selection, a different reported
version, explicit proof-hole/axiom tokens in this file, and Lean warnings/errors.
It prints the version and axiom dependencies. It is a focused hygiene/check recipe,
not an independent proof checker or a general security sandbox. It does not install
anything or change global toolchain configuration. Requalify version upgrades.

Observed successful axiom inventory: commutation and contribution noninterference
`[propext]`; empty-cut, composition and assertion translation
`[propext, Quot.sound]`; absent assertion `[]`. New incoming/unrelated-premise laws
use `[propext]`; lookup idempotence `[propext, Quot.sound]`. No `sorryAx` or custom axiom. The Lean kernel,
compiler/elaborator, and standard-library implementation are trusted here; these
are not axiom-free proofs or proof-checker-independence evidence.

## OCaml mapping and residual gap

`Correction_frontier.lineage` supplies the root/terminal row.
`Reflected_root_cut.create` validates declarations against its immutable frontier,
then uses exact-ID membership to filter rows and project their terminal Events.
The proof's predicate corresponds to this declared finite membership. It ignores
validation, identity transport, payload interpretation, and internal OCaml/Base
algorithms. Tests compare the separate implementation with an integer transitive-
closure/list model and source-list payload oracle; none is a formal refinement.

The quantity specification assigns a signed Int contribution to each terminal at
one coordinate and recursively skips reflected roots. OCaml additionally matches
exact Locus/Measure and sums neutral Effect occurrences through private Effect_sum.
Current_quantity_projection gates by assertion support before exposing a quantity.
Those arithmetic/lookup mechanisms are not formally refined here; direct Zarith
original-Effect/independent cut oracles check separate executable seams.

See [cut](../application/reflected_root_cut.mli),
[quantity](../application/current_quantity_projection.mli) and
[group](../application/current_quantity_groups.mli) interfaces for admission policy;
[verification](../docs/VERIFICATION.md) owns bounded executable evidence. Functional
ownership maps to anonymous premises over one supplied frontier. That extra grouping,
indexing, ordered qualification and reduction are only executable/model-tested,
not formally refined by these three lookup laws. Revisit if ownership/update or filtering
policy, root identity, output order, terminal transformation, or proof assumptions
change. Keep this artifact outside ordinary Dune/opam requirements.
