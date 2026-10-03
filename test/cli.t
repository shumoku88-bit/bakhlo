Global help describes the two concrete operations, not an imaginary UI.

  $ loam-ocaml --help
  Usage: loam-ocaml COMMAND ...
  check-movement --effect LOCUS MEASURE QUANTA [--effect ...]
  inspect-current-fixture FILE LOCUS MEASURE
  Structural validation and read-only synthetic quantity queries.
  Not household admission or authority; no writes.
  Use COMMAND --help for details.

Movement validation keeps exact quantities, typed refusals and honest streams.

  $ loam-ocaml check-movement --effect wallet jpy -18446744073709551616 --effect food jpy 18446744073709551615 --effect food jpy 1
  Movement structurally valid (not recorded).
  Measure: "jpy"
  Effects:
    1. "wallet": -18446744073709551616 quanta
    2. "food": +18446744073709551615 quanta
    3. "food": +1 quanta
  Positive total: 18446744073709551616 quanta
  $ loam-ocaml check-movement --effect wallet jpy -5 --effect food jpy 4 >out 2>err
  [1]
  $ test ! -s out && grep -q 'residual -1' err
  $ loam-ocaml check-movement --effect wallet jpy -5 --effect food usd 5 >out 2>err
  [1]
  $ test ! -s out && grep -q 'differs from' err
  $ loam-ocaml check-movement --effect wallet jpy 1.5 >out 2>err
  [2]
  $ test ! -s out && grep -q 'signed decimal integer' err
  $ loam-ocaml check-movement --file /not-read >out 2>err
  [2]
  $ test ! -s out && grep -q 'unexpected argument' err
  $ loam-ocaml >out 2>err
  [2]
  $ test ! -s out && grep -q 'a command is required' err

One admitted source: independent assertion cuts, origin quantities, known zero and unknown.

  $ cp ../examples/current-preview.fixture current
  $ cp current before
  $ loam-ocaml inspect-current-fixture current wallet jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  $ loam-ocaml inspect-current-fixture current wallet usd
  Conditional current fixture quantity (ordinary base Actual subset).
  exact assertion; "wallet" / "usd": asserted=5; delta=0; quantity=5
  $ loam-ocaml inspect-current-fixture current food jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  "food" / "jpy": zero-origin; quantity=160
  $ loam-ocaml inspect-current-fixture current quiet jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  "quiet" / "jpy": zero-origin; quantity=0
  $ loam-ocaml inspect-current-fixture current empty jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  exact assertion; "empty" / "jpy": asserted=0; delta=0; quantity=0
  $ loam-ocaml inspect-current-fixture current unsupported jpy
  "unsupported" / "jpy": quantity unknown (no supported premise in supplied fixture).
  [3]
  $ cmp current before
  $ loam-ocaml inspect-current-fixture --help
  Usage: loam-ocaml inspect-current-fixture FILE LOCUS MEASURE
  Read ONLY a LOAM-OCAML-ACTUAL-FIXTURE v2 synthetic file; never write.
  Ordinary base Actual subset; separated zero-origin/exact assertion support.
  Not full normalized admission, historical completeness or household authority.
  $ loam-ocaml inspect-current-fixture not-read >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected FILE LOCUS MEASURE' err
  $ loam-ocaml inspect-current-fixture not-present wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Cannot read synthetic fixture' err

Malformed/obsolete inputs and invalid premises refuse globally, never an empty basis.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t1\nEND\n' >obsolete
  $ loam-ocaml inspect-current-fixture obsolete wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'version 2' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEND' >truncated
  $ loam-ocaml inspect-current-fixture truncated wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'must end with newline' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\ta\t1900-02-29\nEND-EVENT\nEND\n' >date
  $ loam-ocaml inspect-current-fixture date wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'invalid ISO occurrence date' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nGROUP\nREFLECT\tabsent\nEND-GROUP\nEND\n' >cut
  $ loam-ocaml inspect-current-fixture cut wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'unknown root' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\ta\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >unbalanced
  $ loam-ocaml inspect-current-fixture unbalanced wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'residual 1' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nZERO-ORIGIN\twallet\tjpy\nGROUP\nASSERT\twallet\tjpy\t0\nEND-GROUP\nEND\n' >overlap
  $ loam-ocaml inspect-current-fixture overlap unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'zero-origin overlaps exact assertion' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nOPENING\twallet\tjpy\ta\nEND\n' >opening
  $ loam-ocaml inspect-current-fixture opening wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
