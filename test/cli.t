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

One admitted source: exact families, known zero, known nonzero/amount-unknown and unsupported.

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
  $ loam-ocaml inspect-current-fixture current offset usd
  Conditional current fixture quantity (ordinary base Actual subset).
  "offset" / "usd": opening Event "b"; quantity=-7
  $ loam-ocaml inspect-current-fixture current quiet jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  "quiet" / "jpy": zero-origin; quantity=0
  $ loam-ocaml inspect-current-fixture current empty jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  exact assertion; "empty" / "jpy": asserted=0; delta=0; quantity=0
  $ loam-ocaml inspect-current-fixture current unsupported jpy
  "unsupported" / "jpy": quantity unknown (no supported premise in supplied fixture).
  [3]
  $ loam-ocaml inspect-current-fixture current pantry jpy
  "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
  [4]
  $ loam-ocaml inspect-current-fixture current stale jpy
  "stale" / "jpy": quantity unknown (no supported premise in supplied fixture).
  [3]
  $ cmp current before
  $ loam-ocaml inspect-current-fixture --help
  Usage: loam-ocaml inspect-current-fixture FILE LOCUS MEASURE
  Read ONLY a LOAM-OCAML-ACTUAL-FIXTURE v2 synthetic file; never write.
  Ordinary base Actual subset; separated origin/opening/assertion/presence support.
  Exit 0 exact, 4 known nonzero (amount unknown), 3 unsupported; stdout.
  Not full normalized admission, historical completeness or household authority.
  $ loam-ocaml inspect-current-fixture not-read >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected FILE LOCUS MEASURE' err
  $ loam-ocaml inspect-current-fixture not-present wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Cannot read synthetic fixture' err

Keyed Effects keep Event-local identity; duplicates are admission errors, not syntax.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\tkey\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >keyed
  $ cp keyed keyed-before
  $ loam-ocaml inspect-current-fixture keyed wallet jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp keyed keyed-before
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\tkey\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t1\nKEYED-EFFECT\tkey\tother\tjpy\t1\nEND-EVENT\nEND\n' >duplicate-key
  $ loam-ocaml inspect-current-fixture duplicate-key unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Effect key "key" at 3 (first 1)' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\t\twallet\tjpy\t1\nEND-EVENT\nEND\n' >empty-key
  $ loam-ocaml inspect-current-fixture empty-key wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'identity must not be empty' err

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
  [1]
  $ test ! -s out && grep -q 'Event "a" is not current' err

Explicit opening zero is not inferred origin; overlaps refuse even an unrelated query.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nOPENING\twallet\tjpy\te\nEND\n' >opening-zero
  $ loam-ocaml inspect-current-fixture opening-zero wallet jpy
  Conditional current fixture quantity (ordinary base Actual subset).
  "wallet" / "jpy": opening Event "e"; quantity=0
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nOPENING\twallet\tjpy\te\nZERO-ORIGIN\twallet\tjpy\nEND\n' >opening-origin
  $ loam-ocaml inspect-current-fixture opening-origin unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'overlaps zero-origin' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nOPENING\twallet\tjpy\te\nGROUP\nASSERT\twallet\tjpy\t0\nEND-GROUP\nEND\n' >opening-assertion
  $ loam-ocaml inspect-current-fixture opening-assertion unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'opening Event "e" overlaps exact assertion' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nGROUP\nOPENING\twallet\tjpy\te\nEND-GROUP\nEND\n' >misplaced-opening
  $ loam-ocaml inspect-current-fixture misplaced-opening wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 3' err

Presence is a separate whole-input premise; malformed/cut/duplicate/overlap never fall back.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nPRESENCE\nPRESENT\twallet\tjpy\nEND-PRESENCE\nEND\n' >presence
  $ cp presence before-presence
  $ loam-ocaml inspect-current-fixture presence wallet jpy >out 2>err
  [4]
  $ test ! -s err && grep -q 'known nonzero' out && ! grep -q 'quantity=' out
  $ cmp presence before-presence
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nPRESENCE\nEND-PRESENCE\nPRESENCE\nEND-PRESENCE\nEND\n' >repeat-presence
  $ loam-ocaml inspect-current-fixture repeat-presence wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'repeated PRESENCE block' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nPRESENCE\nPRESENT\twallet\tjpy\nEND\n' >truncated-presence
  $ loam-ocaml inspect-current-fixture truncated-presence wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 4' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nPRESENCE\nREFLECT\tmissing\nEND-PRESENCE\nEND\n' >presence-cut
  $ loam-ocaml inspect-current-fixture presence-cut unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'presence cut: unknown root' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nPRESENCE\nPRESENT\twallet\tjpy\nPRESENT\twallet\tjpy\nEND-PRESENCE\nEND\n' >presence-duplicate
  $ loam-ocaml inspect-current-fixture presence-duplicate unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate presence.*at 2 (first 1)' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nZERO-ORIGIN\twallet\tjpy\nPRESENCE\nPRESENT\twallet\tjpy\nEND-PRESENCE\nEND\n' >presence-overlap
  $ loam-ocaml inspect-current-fixture presence-overlap unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'presence.*overlaps exact support' err
