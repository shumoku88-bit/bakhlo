Global help describes concrete operations, not an imaginary UI.

  $ bakhlo --help
  Usage: bakhlo COMMAND ...
  check-movement --effect LOCUS MEASURE QUANTA [--effect ...]
  inspect-current-fixture FILE LOCUS MEASURE
  inspect-current-text FILE LOCUS MEASURE
  inspect-loam-quantity FILE LOCUS MEASURE
  Structural validation and read-only conditional quantity queries.
  Not household admission or authority; no writes.
  Use COMMAND --help for details.

Movement validation keeps exact quantities, typed refusals and honest streams.

  $ bakhlo check-movement --effect wallet jpy -18446744073709551616 --effect food jpy 18446744073709551615 --effect food jpy 1
  Movement structurally valid (not recorded).
  Measure: "jpy"
  Effects:
    1. "wallet": -18446744073709551616 quanta
    2. "food": +18446744073709551615 quanta
    3. "food": +1 quanta
  Positive total: 18446744073709551616 quanta
  $ bakhlo check-movement --effect wallet jpy -5 --effect food jpy 4 >out 2>err
  [1]
  $ test ! -s out && grep -q 'residual -1' err
  $ bakhlo check-movement --effect wallet jpy -5 --effect food usd 5 >out 2>err
  [1]
  $ test ! -s out && grep -q 'differs from' err
  $ bakhlo check-movement --effect wallet jpy 1.5 >out 2>err
  [2]
  $ test ! -s out && grep -q 'signed decimal integer' err
  $ bakhlo check-movement --file /not-read >out 2>err
  [2]
  $ test ! -s out && grep -q 'unexpected argument' err
  $ bakhlo >out 2>err
  [2]
  $ test ! -s out && grep -q 'a command is required' err

One admitted source: exact families, known zero, known nonzero/amount-unknown and unsupported.

  $ cp ../examples/current-preview.fixture current
  $ cp current before
  $ bakhlo inspect-current-fixture current wallet jpy
  Conditional current fixture quantity (Actual subset).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  $ bakhlo inspect-current-fixture current wallet usd
  Conditional current fixture quantity (Actual subset).
  exact assertion; "wallet" / "usd": asserted=5; delta=0; quantity=5
  $ bakhlo inspect-current-fixture current food jpy
  Conditional current fixture quantity (Actual subset).
  "food" / "jpy": zero-origin; quantity=160
  $ bakhlo inspect-current-fixture current offset usd
  Conditional current fixture quantity (Actual subset).
  "offset" / "usd": opening Event "b"; quantity=-7
  $ bakhlo inspect-current-fixture current quiet jpy
  Conditional current fixture quantity (Actual subset).
  "quiet" / "jpy": zero-origin; quantity=0
  $ bakhlo inspect-current-fixture current empty jpy
  Conditional current fixture quantity (Actual subset).
  exact assertion; "empty" / "jpy": asserted=0; delta=0; quantity=0
  $ bakhlo inspect-current-fixture current unsupported jpy
  "unsupported" / "jpy": quantity unknown (no supported premise in supplied evidence).
  [3]
  $ bakhlo inspect-current-fixture current pantry jpy
  "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
  [4]
  $ bakhlo inspect-current-fixture current stale jpy
  "stale" / "jpy": quantity unknown (no supported premise in supplied evidence).
  [3]
  $ cmp current before
  $ bakhlo inspect-current-fixture --help
  Usage: bakhlo inspect-current-fixture FILE LOCUS MEASURE
  Read ONLY a BAKHLO-ACTUAL-FIXTURE v2 synthetic file; never write.
  Actual subset; separated origin/opening/assertion/presence support.
  Exit 0 exact, 4 known nonzero (amount unknown), 3 unsupported; stdout.
  Not full normalized admission, historical completeness or household authority.
  $ bakhlo inspect-current-fixture not-read >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected FILE LOCUS MEASURE' err
  $ bakhlo inspect-current-fixture not-present wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Cannot read synthetic fixture' err

Keyed Effects keep Event-local identity; duplicates are admission errors, not syntax.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\tkey\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >keyed
  $ cp keyed keyed-before
  $ bakhlo inspect-current-fixture keyed wallet jpy
  Conditional current fixture quantity (Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp keyed keyed-before
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\tkey\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t1\nKEYED-EFFECT\tkey\tother\tjpy\t1\nEND-EVENT\nEND\n' >duplicate-key
  $ bakhlo inspect-current-fixture duplicate-key unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Effect key "key" at 3 (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\t\twallet\tjpy\t1\nEND-EVENT\nEND\n' >empty-key
  $ bakhlo inspect-current-fixture empty-key wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'identity must not be empty' err

Date revisions are independent of Event corrections; no default or latest-date winner.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nVALIDITY-CORRECTION\tBASE\te\te\nVALIDITY-REVISION\te\te\t1900-01-01\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >revised-date
  $ cp revised-date revised-date-before
  $ bakhlo inspect-current-fixture revised-date wallet jpy
  Conditional current fixture quantity (Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp revised-date revised-date-before
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\nEND-EVENT\nVALIDITY-REVISION\tr\te\t2000-02-29\nZERO-ORIGIN\twallet\tjpy\nEND\n' >revision-only
  $ bakhlo inspect-current-fixture revision-only wallet jpy >out 2>err
  $ test ! -s err && grep -q 'quantity=0' out
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\nEND-EVENT\nEND\n' >missing-date
  $ bakhlo inspect-current-fixture missing-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'missing current validity' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nVALIDITY-REVISION\tr\te\t1900-01-01\nEND\n' >ambiguous-date
  $ bakhlo inspect-current-fixture ambiguous-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'multiple current validities' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nVALIDITY-CORRECTION\tBASE\te\tmissing\nEND\n' >open-date
  $ bakhlo inspect-current-fixture open-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'validity correction 1: missing replacement=revision "missing"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nVALIDITY-REVISION\tr\te\t1900-02-29\nVALIDITY-CORRECTION\tBASE\te\tr\nEND\n' >invalid-revised-date
  $ bakhlo inspect-current-fixture invalid-revised-date unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'invalid ISO occurrence date' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nVALIDITY-CORRECTION\tEVENT\te\tr\nEND\n' >bad-date-target
  $ bakhlo inspect-current-fixture bad-date-target wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected BASE or REVISION' err

Optional Event descriptions retain recognition text; duplicates/references refuse globally.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDESCRIPTION\ta\t retained root text \nDESCRIPTION\tb\t\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nZERO-ORIGIN\twallet\tjpy\nEND\n' >described
  $ cp described described-before
  $ bakhlo inspect-current-fixture described wallet jpy
  Conditional current fixture quantity (Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp described described-before
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nDESCRIPTION\te\tsame\nDESCRIPTION\te\tsame\nEND\n' >duplicate-description
  $ bakhlo inspect-current-fixture duplicate-description unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate description for "e" at 2 (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDESCRIPTION\tunknown\ttext\nEND\n' >unknown-description
  $ bakhlo inspect-current-fixture unknown-description unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'description 1: unknown Event "unknown"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDESCRIPTION\te\nEND\n' >malformed-description
  $ bakhlo inspect-current-fixture malformed-description wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nDESCRIPTION\te\topening balance\nEND\n' >description-only
  $ bakhlo inspect-current-fixture description-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nPURPOSE\te\tstructured meaning\nEND\n' >unqualified-metadata
  $ bakhlo inspect-current-fixture unqualified-metadata wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'unknown, malformed or misplaced' err

Merchant dispositions are explicit retained evidence, never default classification or support.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nMERCHANT\ta\t provider \nNONMERCHANT\tb\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nZERO-ORIGIN\twallet\tjpy\nEND\n' >merchants
  $ cp merchants merchants-before
  $ bakhlo inspect-current-fixture merchants wallet jpy
  Conditional current fixture quantity (Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp merchants merchants-before
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nMERCHANT\te\tp\nMERCHANT\te\tp\nEND\n' >duplicate-merchant
  $ bakhlo inspect-current-fixture duplicate-merchant unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Merchant disposition for "e" at 2 (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nMERCHANT\te\tp\nNONMERCHANT\te\nEND\n' >conflicting-merchant
  $ bakhlo inspect-current-fixture conflicting-merchant unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Merchant disposition' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nNONMERCHANT\tunknown\nEND\n' >unknown-merchant
  $ bakhlo inspect-current-fixture unknown-merchant unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Merchant disposition 1: unknown Event "unknown"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nMERCHANT\te\nEND\n' >malformed-merchant
  $ bakhlo inspect-current-fixture malformed-merchant wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nMERCHANT\te\t\nEND\n' >empty-party
  $ bakhlo inspect-current-fixture empty-party wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'identity must not be empty' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nNONMERCHANT\te\nEND\n' >nonmerchant-only
  $ bakhlo inspect-current-fixture nonmerchant-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nMERCHANT\te\tp\nEND\n' >merchant-only
  $ bakhlo inspect-current-fixture merchant-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out

Original amounts address stable roots, not balances or current-terminal subjects.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nORIGINAL-AMOUNT\ta\t eur \t+100\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nZERO-ORIGIN\twallet\tjpy\nEND\n' >original-amount
  $ cp original-amount original-amount-before
  $ bakhlo inspect-current-fixture original-amount wallet jpy
  Conditional current fixture quantity (Actual subset).
  "wallet" / "jpy": zero-origin; quantity=0
  $ cmp original-amount original-amount-before
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nORIGINAL-AMOUNT\te\tusd\t1\nORIGINAL-AMOUNT\te\tusd\t1\nEND\n' >duplicate-amount
  $ bakhlo inspect-current-fixture duplicate-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate original amount for root "e" at 2 (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nORIGINAL-AMOUNT\te\tusd\t0\nEND\n' >zero-amount
  $ bakhlo inspect-current-fixture zero-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'nonpositive quantity 0' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nORIGINAL-AMOUNT\tunknown\tusd\t1\nEND\n' >unknown-amount
  $ bakhlo inspect-current-fixture unknown-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'original amount 1: unknown Event "unknown"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tb\t2026-10-02\nEND-EVENT\nCORRECTION\ta\tb\nORIGINAL-AMOUNT\tb\tusd\t1\nEND\n' >nonroot-amount
  $ bakhlo inspect-current-fixture nonroot-amount unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Event "b" is not a correction root' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nORIGINAL-AMOUNT\te\tusd\t1.0\nEND\n' >malformed-amount
  $ bakhlo inspect-current-fixture malformed-amount wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected signed decimal integer' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEND-EVENT\nORIGINAL-AMOUNT\te\tjpy\t1\nEND\n' >amount-only
  $ bakhlo inspect-current-fixture amount-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out

Exchange is a selected-key exception, never inferred balance/support or correction replacement.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEXCHANGE\te\ts\td\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-100\nKEYED-EFFECT\td\twallet\tusd\t2\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nZERO-ORIGIN\twallet\tusd\nEND\n' >exchange
  $ cp exchange exchange-before
  $ bakhlo inspect-current-fixture exchange wallet jpy
  Conditional current fixture quantity (Actual subset).
  "wallet" / "jpy": zero-origin; quantity=-101
  $ bakhlo inspect-current-fixture exchange wallet usd
  Conditional current fixture quantity (Actual subset).
  "wallet" / "usd": zero-origin; quantity=2
  $ cmp exchange exchange-before
  $ grep -v '^EXCHANGE' exchange >unclaimed-exchange
  $ bakhlo inspect-current-fixture unclaimed-exchange wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'residual -101' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-1\nKEYED-EFFECT\td\twallet\tusd\t1\nEND-EVENT\nEXCHANGE\te\ts\td\nEXCHANGE\te\ts\td\nEND\n' >duplicate-exchange
  $ bakhlo inspect-current-fixture duplicate-exchange unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Exchange for "e" at 2 (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEXCHANGE\tmissing\ts\td\nEND\n' >unknown-exchange
  $ bakhlo inspect-current-fixture unknown-exchange unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Exchange 1: unknown Event "missing"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t-1\nKEYED-EFFECT\td\twallet\tusd\t1\nEND-EVENT\nEXCHANGE\te\ts\td\nEND\n' >anonymous-exchange
  $ bakhlo inspect-current-fixture anonymous-exchange unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'missing source Effect key "s"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-1\nKEYED-EFFECT\td\twallet\tusd\t1\nEFFECT\toffset\teur\t1\nEND-EVENT\nEXCHANGE\te\ts\td\nEND\n' >third-measure
  $ bakhlo inspect-current-fixture third-measure unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'third Measure "eur" at Effect 3' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-1\nKEYED-EFFECT\td\twallet\tusd\t1\nEFFECT\toffset\tjpy\t1\nEND-EVENT\nEXCHANGE\te\ts\td\nEND\n' >zero-source-total
  $ bakhlo inspect-current-fixture zero-source-total unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'source Measure "jpy" total 0 is not negative' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-1\nKEYED-EFFECT\td\twallet\tusd\t1\nEFFECT\toffset\tusd\t0\nEND-EVENT\nEXCHANGE\te\ts\td\nEND\n' >zero-extra
  $ bakhlo inspect-current-fixture zero-extra unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'zero Effect at 3' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-1\nKEYED-EFFECT\td\twallet\tusd\t1\nEND-EVENT\nEVENT\tx\t2026-10-03\nEND-EVENT\nEXCHANGE\te\ts\td\nCORRECTION\tx\te\nEND\n' >corrected-exchange
  $ bakhlo inspect-current-fixture corrected-exchange unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'participates in correction' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEXCHANGE\te\ts\nEND\n' >malformed-exchange
  $ bakhlo inspect-current-fixture malformed-exchange wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ grep -v '^ZERO-ORIGIN' exchange >exchange-only
  $ bakhlo inspect-current-fixture exchange-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out

Effect-backed relation units keep explicit direction/identity; never manufacture current balance support.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tborrow\te\ts\tHOUSEHOLD\tEXTERNAL\tperson\t1\nRELATION\tlend\te\ts\tEXTERNAL\tperson\tHOUSEHOLD\t1\nEVENT\te\t1900-01-01\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >relations
  $ cp relations before-relations
  $ bakhlo inspect-current-fixture relations wallet jpy >out 2>err
  $ test ! -s err && grep -q 'quantity=-2' out
  $ cmp relations before-relations
  $ grep -v '^ZERO-ORIGIN' relations >relations-only
  $ bakhlo inspect-current-fixture relations-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\te\ts\tHOUSEHOLD\tEXTERNAL\tp\t2\nRELATION\ty\te\ts\tEXTERNAL\tq\tHOUSEHOLD\t1\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEND\n' >overcovered-relations
  $ bakhlo inspect-current-fixture overcovered-relations unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'coverage 3 exceeds source magnitude 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\tabsent\ts\tHOUSEHOLD\tEXTERNAL\tp\t1\nRELATION\tx\tabsent\ts\tHOUSEHOLD\tEXTERNAL\tp\t1\nEND\n' >duplicate-relations
  $ bakhlo inspect-current-fixture duplicate-relations unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate Relation "x" at 2 (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\tabsent\ts\tHOUSEHOLD\tEXTERNAL\tp\t1\nEND\n' >open-relation
  $ bakhlo inspect-current-fixture open-relation unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'unknown Event "absent"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\te\ts\tHOUSEHOLD\tEXTERNAL\tp\t1\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEND\n' >anonymous-relation
  $ bakhlo inspect-current-fixture anonymous-relation unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'has no Effect key "s"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\te\ts\tHOUSEHOLD\tHOUSEHOLD\t1\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEND\n' >invalid-relation-endpoints
  $ bakhlo inspect-current-fixture invalid-relation-endpoints unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'expected one Household and one External endpoint' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\te\ts\tHOUSEHOLD\tEXTERNAL\tp\t0\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEND\n' >zero-relation
  $ bakhlo inspect-current-fixture zero-relation unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'quantity 0 is not positive' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\te\ts\tHOUSEHOLD\tEXTERNAL\tp\t3\nEVENT\te\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEND\n' >oversized-relation
  $ bakhlo inspect-current-fixture oversized-relation unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'quantity 3 exceeds source magnitude 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\te\ts\tEXTERNAL\t\tHOUSEHOLD\t1\nEND\n' >empty-relation-party
  $ bakhlo inspect-current-fixture empty-relation-party wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'identity must not be empty' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\te\ts\tHOUSEHOLD\tEXTERNAL\tp\nEND\n' >malformed-relation
  $ bakhlo inspect-current-fixture malformed-relation wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected relation quantity' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nGROUP\nRELATION\tx\te\ts\tHOUSEHOLD\tEXTERNAL\tp\t1\nEND-GROUP\nEND\n' >misplaced-relation
  $ bakhlo inspect-current-fixture misplaced-relation wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 3' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\te\tx\t1\nEND\n' >open-discharge
  $ bakhlo inspect-current-fixture open-discharge wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Discharge 1: unknown Event "e"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nRELATION\tx\033\tabsent\ts\tHOUSEHOLD\tEXTERNAL\tp\t1\nEND\n' >escaped-relation
  $ bakhlo inspect-current-fixture escaped-relation unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -Fq '"x\027"' err

Exact discharge is retained provenance, not a new physical Effect or implicit balance support.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tr\t1\nDISCHARGE\td\tr\t1\nRELATION\tr\ta\ts\tHOUSEHOLD\tEXTERNAL\tp\t2\nEVENT\ta\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEVENT\tc\t1900-01-01\nEND-EVENT\nEVENT\td\t1900-01-01\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >discharges
  $ cp discharges before-discharges
  $ bakhlo inspect-current-fixture discharges wallet jpy >out 2>err
  $ test ! -s err && grep -q 'quantity=-2' out
  $ cmp discharges before-discharges
  $ grep -v '^ZERO-ORIGIN' discharges >discharges-only
  $ bakhlo inspect-current-fixture discharges-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tr\t2\nDISCHARGE\td\tr\t1\nRELATION\tr\ta\ts\tHOUSEHOLD\tEXTERNAL\tp\t2\nEVENT\ta\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEVENT\tc\t1900-01-01\nEND-EVENT\nEVENT\td\t1900-01-01\nEND-EVENT\nEND\n' >over-discharged
  $ bakhlo inspect-current-fixture over-discharged unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Relation "r" total 3 exceeds target quantity 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tr\t1\nDISCHARGE\tc\tr\t1\nRELATION\tr\ta\ts\tHOUSEHOLD\tEXTERNAL\tp\t2\nEVENT\ta\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEVENT\tc\t1900-01-01\nEND-EVENT\nEND\n' >duplicate-discharge
  $ bakhlo inspect-current-fixture duplicate-discharge unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Discharge 2: repeated Event "c" / Relation "r" (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\ta\tr\t1\nRELATION\tr\ta\ts\tHOUSEHOLD\tEXTERNAL\tp\t2\nEVENT\ta\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEND\n' >self-discharge
  $ bakhlo inspect-current-fixture self-discharge unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Event "a" established target Relation "r"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tmissing\t1\nEVENT\tc\t1900-01-01\nEND-EVENT\nEND\n' >missing-discharge-target
  $ bakhlo inspect-current-fixture missing-discharge-target unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'unknown Relation "missing"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tr\t0\nRELATION\tr\ta\ts\tHOUSEHOLD\tEXTERNAL\tp\t2\nEVENT\ta\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEVENT\tc\t1900-01-01\nEND-EVENT\nEND\n' >zero-discharge
  $ bakhlo inspect-current-fixture zero-discharge unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'quantity 0 is not positive' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tr\t3\nRELATION\tr\ta\ts\tHOUSEHOLD\tEXTERNAL\tp\t2\nEVENT\ta\t2026-10-03\nKEYED-EFFECT\ts\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEVENT\tc\t1900-01-01\nEND-EVENT\nEND\n' >oversized-discharge
  $ bakhlo inspect-current-fixture oversized-discharge unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'quantity 3 exceeds target quantity 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tr\nEND\n' >malformed-discharge
  $ bakhlo inspect-current-fixture malformed-discharge wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\t\t1\nEND\n' >empty-discharge-target
  $ bakhlo inspect-current-fixture empty-discharge-target wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'identity must not be empty' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nGROUP\nDISCHARGE\tc\tr\t1\nEND-GROUP\nEND\n' >misplaced-discharge
  $ bakhlo inspect-current-fixture misplaced-discharge wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 3' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nDISCHARGE\tc\tx\033\t1\nEVENT\tc\t1900-01-01\nEND-EVENT\nEND\n' >escaped-discharge
  $ bakhlo inspect-current-fixture escaped-discharge unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -Fq '"x\027"' err

Explicit Reversal retains both Events and exact physical multiplicity; no support inferred.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\ta\tr\nEVENT\tr\t1900-01-01\nEFFECT\twallet\tjpy\t3\nEFFECT\toffset\tjpy\t-3\nEND-EVENT\nEVENT\ta\t2026-10-03\nKEYED-EFFECT\tphysical\twallet\tjpy\t-3\nEFFECT\toffset\tjpy\t3\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >reversal
  $ cp reversal before-reversal
  $ bakhlo inspect-current-fixture reversal wallet jpy >out 2>err
  $ test ! -s err && grep -q 'quantity=0' out
  $ cmp reversal before-reversal
  $ grep -v '^ZERO-ORIGIN' reversal >reversal-only
  $ bakhlo inspect-current-fixture reversal-only wallet jpy >out 2>err
  [3]
  $ test ! -s err && grep -q 'quantity unknown' out
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\ta\tr\nEVENT\ta\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t1\nEFFECT\toffset\tjpy\t-2\nEND-EVENT\nEVENT\tr\t2026-10-03\nEFFECT\twallet\tjpy\t-2\nEFFECT\toffset\tjpy\t2\nEND-EVENT\nEND\n' >regrouped
  $ bakhlo inspect-current-fixture regrouped unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'not the exact physical inverse' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\tt\tr\nEVENT\tt\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEND-EVENT\nEVENT\tr\t2026-10-03\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nEND\n' >unbalanced-pair
  $ bakhlo inspect-current-fixture unbalanced-pair unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Event "t" at 1.*residual 1' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\ta\tr\nREVERSAL\tr\ta\nEVENT\ta\t2026-10-03\nEND-EVENT\nEVENT\tr\t2026-10-03\nEND-EVENT\nEND\n' >reversal-cycle
  $ bakhlo inspect-current-fixture reversal-cycle unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'Reversal 2: repeated target Event "r" (first reversal at 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\ta\ta\nEND\n' >self-reversal
  $ bakhlo inspect-current-fixture self-reversal unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'repeated reversal Event "a" (first target at 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\ta\tr\nEND\n' >open-reversal
  $ bakhlo inspect-current-fixture open-reversal unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'missing target Event "a", reversal Event "r"' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\tx\tr\nEVENT\tx\t2026-10-03\nEFFECT\twallet\tjpy\t0\nEND-EVENT\nEVENT\tr\t2026-10-03\nEFFECT\twallet\tjpy\t0\nEND-EVENT\nEND\n' >zero-reversal
  $ bakhlo inspect-current-fixture zero-reversal unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'zero Effect at 1' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\ta\nEND\n' >malformed-reversal
  $ bakhlo inspect-current-fixture malformed-reversal wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\t\tr\nEND\n' >empty-reversal
  $ bakhlo inspect-current-fixture empty-reversal wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'identity must not be empty' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nGROUP\nREVERSAL\ta\tr\nEND-GROUP\nEND\n' >misplaced-reversal
  $ bakhlo inspect-current-fixture misplaced-reversal wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 3' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nREVERSAL\tx\033\tr\nEND\n' >escaped-reversal
  $ bakhlo inspect-current-fixture escaped-reversal unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -Fq '"x\027"' err

Malformed/obsolete inputs and invalid premises refuse globally, never an empty basis.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t1\nEND\n' >obsolete
  $ bakhlo inspect-current-fixture obsolete wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'version 2' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEND' >truncated
  $ bakhlo inspect-current-fixture truncated wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'must end with newline' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\ta\t1900-02-29\nEND-EVENT\nEND\n' >date
  $ bakhlo inspect-current-fixture date wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'invalid ISO occurrence date' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nGROUP\nREFLECT\tabsent\nEND-GROUP\nEND\n' >cut
  $ bakhlo inspect-current-fixture cut wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'unknown root' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\ta\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEND-EVENT\nZERO-ORIGIN\twallet\tjpy\nEND\n' >unbalanced
  $ bakhlo inspect-current-fixture unbalanced wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'residual 1' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nZERO-ORIGIN\twallet\tjpy\nGROUP\nASSERT\twallet\tjpy\t0\nEND-GROUP\nEND\n' >overlap
  $ bakhlo inspect-current-fixture overlap unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'zero-origin overlaps exact assertion' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nOPENING\twallet\tjpy\ta\nEND\n' >opening
  $ bakhlo inspect-current-fixture opening wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Event "a" is not current' err

Explicit opening zero is not inferred origin; overlaps refuse even an unrelated query.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nOPENING\twallet\tjpy\te\nEND\n' >opening-zero
  $ bakhlo inspect-current-fixture opening-zero wallet jpy
  Conditional current fixture quantity (Actual subset).
  "wallet" / "jpy": opening Event "e"; quantity=0
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nOPENING\twallet\tjpy\te\nZERO-ORIGIN\twallet\tjpy\nEND\n' >opening-origin
  $ bakhlo inspect-current-fixture opening-origin unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'overlaps zero-origin' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nEVENT\te\t2026-10-03\nEFFECT\twallet\tjpy\t1\nEFFECT\twallet\tjpy\t-1\nEND-EVENT\nOPENING\twallet\tjpy\te\nGROUP\nASSERT\twallet\tjpy\t0\nEND-GROUP\nEND\n' >opening-assertion
  $ bakhlo inspect-current-fixture opening-assertion unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'opening Event "e" overlaps exact assertion' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nGROUP\nOPENING\twallet\tjpy\te\nEND-GROUP\nEND\n' >misplaced-opening
  $ bakhlo inspect-current-fixture misplaced-opening wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 3' err

Presence is a separate whole-input premise; malformed/cut/duplicate/overlap never fall back.

  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nPRESENCE\nPRESENT\twallet\tjpy\nEND-PRESENCE\nEND\n' >presence
  $ cp presence before-presence
  $ bakhlo inspect-current-fixture presence wallet jpy >out 2>err
  [4]
  $ test ! -s err && grep -q 'known nonzero' out && ! grep -q 'quantity=' out
  $ cmp presence before-presence
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nPRESENCE\nEND-PRESENCE\nPRESENCE\nEND-PRESENCE\nEND\n' >repeat-presence
  $ bakhlo inspect-current-fixture repeat-presence wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'repeated PRESENCE block' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nPRESENCE\nPRESENT\twallet\tjpy\nEND\n' >truncated-presence
  $ bakhlo inspect-current-fixture truncated-presence wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'fixture line 4' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nPRESENCE\nREFLECT\tmissing\nEND-PRESENCE\nEND\n' >presence-cut
  $ bakhlo inspect-current-fixture presence-cut unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'presence cut: unknown root' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nPRESENCE\nPRESENT\twallet\tjpy\nPRESENT\twallet\tjpy\nEND-PRESENCE\nEND\n' >presence-duplicate
  $ bakhlo inspect-current-fixture presence-duplicate unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'duplicate presence.*at 2 (first 1)' err
  $ printf 'BAKHLO-ACTUAL-FIXTURE\t2\nZERO-ORIGIN\twallet\tjpy\nPRESENCE\nPRESENT\twallet\tjpy\nEND-PRESENCE\nEND\n' >presence-overlap
  $ bakhlo inspect-current-fixture presence-overlap unrelated usd >out 2>err
  [1]
  $ test ! -s out && grep -q 'presence.*overlaps exact support' err
