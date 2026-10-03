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
  Conditional current fixture quantity (ordinary Actual subset).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  $ loam-ocaml inspect-current-fixture current wallet usd
  Conditional current fixture quantity (ordinary Actual subset).
  exact assertion; "wallet" / "usd": asserted=5; delta=0; quantity=5
  $ loam-ocaml inspect-current-fixture current food jpy
  Conditional current fixture quantity (ordinary Actual subset).
  "food" / "jpy": zero-origin; quantity=160
  $ loam-ocaml inspect-current-fixture current offset usd
  Conditional current fixture quantity (ordinary Actual subset).
  "offset" / "usd": opening Event "b"; quantity=-7
  $ loam-ocaml inspect-current-fixture current quiet jpy
  Conditional current fixture quantity (ordinary Actual subset).
  "quiet" / "jpy": zero-origin; quantity=0
  $ loam-ocaml inspect-current-fixture current empty jpy
  Conditional current fixture quantity (ordinary Actual subset).
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
  Ordinary Actual subset; separated origin/opening/assertion/presence support.
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
  Conditional current fixture quantity (ordinary Actual subset).
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

Date revisions are independent of Event corrections; no default or latest-date winner.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nVALIDITY-CORRECTION\tBASE\te\te\nVALIDITY-REVISION\te\te\t1900-01-01\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >revised-date
  $ cp revised-date revised-date-before
  $ loam-ocaml inspect-current-fixture revised-date wallet jpy
  Conditional current fixture quantity (ordinary Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp revised-date revised-date-before
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\nEND-EVENT\nVALIDITY-REVISION\tr\te\t2000-02-29\nZERO-ORIGIN\twallet\tjpy\nEND\n' >revision-only
  $ loam-ocaml inspect-current-fixture revision-only wallet jpy >out 2>err
  $ test ! -s err && grep -q 'quantity=0' out
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\nEND-EVENT\nEND\n' >missing-date
  $ loam-ocaml inspect-current-fixture missing-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'missing current validity' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nVALIDITY-REVISION\tr\te\t1900-01-01\nEND\n' >ambiguous-date
  $ loam-ocaml inspect-current-fixture ambiguous-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'multiple current validities' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nVALIDITY-CORRECTION\tBASE\te\tmissing\nEND\n' >open-date
  $ loam-ocaml inspect-current-fixture open-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'validity correction 1: missing replacement=revision "missing"' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nVALIDITY-REVISION\tr\te\t1900-02-29\nVALIDITY-CORRECTION\tBASE\te\tr\nEND\n' >invalid-revised-date
  $ loam-ocaml inspect-current-fixture invalid-revised-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'invalid ISO occurrence date' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nVALIDITY-CORRECTION\tEVENT\te\tr\nEND\n' >bad-date-target
  $ loam-ocaml inspect-current-fixture bad-date-target wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected BASE or REVISION' err

Optional Event descriptions retain recognition text; duplicates/references refuse globally.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nDESCRIPTION\ta\t retained root text \nDESCRIPTION\tb\t\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nZERO-ORIGIN\twallet\tjpy\nEND\n' >described
  $ cp described described-before
  $ loam-ocaml inspect-current-fixture described wallet jpy
  Conditional current fixture quantity (ordinary Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp described described-before
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nDESCRIPTION\te\tsame\nDESCRIPTION\te\tsame\nEND\n' >duplicate-description
  $ loam-ocaml inspect-current-fixture duplicate-description unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate description for "e" at 2 (first 1)' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nDESCRIPTION\tunknown\ttext\nEND\n' >unknown-description
  $ loam-ocaml inspect-current-fixture unknown-description unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'description 1: unknown Event "unknown"' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nDESCRIPTION\te\nEND\n' >malformed-description
  $ loam-ocaml inspect-current-fixture malformed-description wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nDESCRIPTION\te\topening balance\nEND\n' >description-only
  $ loam-ocaml inspect-current-fixture description-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nPURPOSE\te\tstructured meaning\nEND\n' >unqualified-metadata
  $ loam-ocaml inspect-current-fixture unqualified-metadata wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'unknown, malformed or misplaced' err

Merchant dispositions are explicit retained evidence, never default classification or support.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nMERCHANT\ta\t provider \nNONMERCHANT\tb\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nZERO-ORIGIN\twallet\tjpy\nEND\n' >merchants
  $ cp merchants merchants-before
  $ loam-ocaml inspect-current-fixture merchants wallet jpy
  Conditional current fixture quantity (ordinary Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp merchants merchants-before
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nMERCHANT\te\tp\nMERCHANT\te\tp\nEND\n' >duplicate-merchant
  $ loam-ocaml inspect-current-fixture duplicate-merchant unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Merchant disposition for "e" at 2 (first 1)' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nMERCHANT\te\tp\nNONMERCHANT\te\nEND\n' >conflicting-merchant
  $ loam-ocaml inspect-current-fixture conflicting-merchant unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Merchant disposition' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nNONMERCHANT\tunknown\nEND\n' >unknown-merchant
  $ loam-ocaml inspect-current-fixture unknown-merchant unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Merchant disposition 1: unknown Event "unknown"' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nMERCHANT\te\nEND\n' >malformed-merchant
  $ loam-ocaml inspect-current-fixture malformed-merchant wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nMERCHANT\te\t\nEND\n' >empty-party
  $ loam-ocaml inspect-current-fixture empty-party wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'identity must not be empty' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nNONMERCHANT\te\nEND\n' >nonmerchant-only
  $ loam-ocaml inspect-current-fixture nonmerchant-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nMERCHANT\te\tp\nEND\n' >merchant-only
  $ loam-ocaml inspect-current-fixture merchant-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out

Original amounts address stable roots, not balances or current-terminal subjects.

  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nORIGINAL-AMOUNT\ta\t eur \t+100\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nZERO-ORIGIN\twallet\tjpy\nEND\n' >original-amount
  $ cp original-amount original-amount-before
  $ loam-ocaml inspect-current-fixture original-amount wallet jpy
  Conditional current fixture quantity (ordinary Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp original-amount original-amount-before
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nORIGINAL-AMOUNT\te\tusd\t1\nORIGINAL-AMOUNT\te\tusd\t1\nEND\n' >duplicate-amount
  $ loam-ocaml inspect-current-fixture duplicate-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate original amount for root "e" at 2 (first 1)' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nORIGINAL-AMOUNT\te\tusd\t0\nEND\n' >zero-amount
  $ loam-ocaml inspect-current-fixture zero-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'nonpositive quantity 0' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nORIGINAL-AMOUNT\tunknown\tusd\t1\nEND\n' >unknown-amount
  $ loam-ocaml inspect-current-fixture unknown-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'original amount 1: unknown Event "unknown"' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nORIGINAL-AMOUNT\tb\tusd\t1\nEND\n' >nonroot-amount
  $ loam-ocaml inspect-current-fixture nonroot-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Event "b" is not a correction root' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nORIGINAL-AMOUNT\te\tusd\t1.0\nEND\n' >malformed-amount
  $ loam-ocaml inspect-current-fixture malformed-amount wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected signed decimal integer' err
  $ printf 'LOAM-OCAML-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nORIGINAL-AMOUNT\te\tjpy\t1\nEND\n' >amount-only
  $ loam-ocaml inspect-current-fixture amount-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out

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
  Conditional current fixture quantity (ordinary Actual subset).
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
