# Optional root-cut and conditional quantity specification experiment

This is development evidence, **not a product build/test/release dependency**.
No upstream source is imported, no Lake project or OCaml binding is involved,
and no second operational engine exists. `tools/check` does not invoke this check.

## Question and statements

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
`[propext, Quot.sound]`; absent assertion `[]`. No `sorryAx` or custom axiom. The Lean kernel,
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

See [cut contract](../docs/ROOT_CUT_SLICE.md) and
[quantity contract](../docs/CURRENT_QUANTITY_SLICE.md) for admission
policy, bounded model/code tests, and actual qualification. Revisit if filtering
policy, root identity, output order, terminal transformation, or proof assumptions
change. Keep this artifact outside ordinary Dune/opam requirements.
