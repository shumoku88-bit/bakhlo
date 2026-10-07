Explicit exchange records two Measures without inventing a rate. Local spending remains an ordinary single-Measure record.

  $ cp ../examples/ordinary-sexp/travel.sexp base.sexp
  $ bakhlo exchange --book base.sexp --out exchanged.sexp --date 2026-10-20 --id exchange-out --from bank-jpy jpy 10000 --to cash-eur eur 6000 --desc "cash exchange"
  S-expression candidate staged; not recording or durable Saved.
  $ bakhlo inspect-current-sexp exchanged.sexp bank-jpy jpy cash-eur eur | grep -E 'quantity=0|quantity=6000'
  exact assertion; "bank-jpy" / "jpy": asserted=10000; delta=-10000; quantity=0
  "cash-eur" / "eur": zero-origin; quantity=6000

A spend in the received currency uses the ordinary record path.

  $ bakhlo record --book exchanged.sexp --out spent.sexp --date 2026-10-21 --id local-spend --measure eur --from cash-eur --to food --amount 1500 --desc "local meal" >/dev/null
  $ bakhlo inspect-current-sexp spent.sexp cash-eur eur food eur | grep -E 'quantity=4500|quantity=1500'
  "cash-eur" / "eur": zero-origin; quantity=4500
  "food" / "eur": zero-origin; quantity=1500

The remaining cash can be exchanged back with the direction reversed.

  $ bakhlo exchange --book spent.sexp --out returned.sexp --date 2026-10-30 --id exchange-back --from cash-eur eur 4500 --to bank-jpy jpy 8000 --desc "return exchange"
  S-expression candidate staged; not recording or durable Saved.
  $ bakhlo inspect-current-sexp returned.sexp bank-jpy jpy cash-eur eur food eur | grep -E 'quantity=8000|quantity=0|quantity=1500'
  exact assertion; "bank-jpy" / "jpy": asserted=10000; delta=-2000; quantity=8000
  "cash-eur" / "eur": zero-origin; quantity=0
  "food" / "eur": zero-origin; quantity=1500

Exchange is explicit, not a generic mixed-Measure escape hatch.

  $ bakhlo exchange --book base.sexp --out bad.sexp --date 2026-10-20 --id same --from bank-jpy jpy 100 --to cash-eur jpy 100 >out 2>err
  [2]
  $ test ! -e bad.sexp && test ! -s out && grep -q 'Measure' err

Version 2 is never silently upgraded just because the caller asks for exchange.

  $ sed 's/(bakhlo 3 ordinary-quantity)/(bakhlo 2 ordinary-quantity)/; s/ exchanges//' base.sexp >v2.sexp
  $ bakhlo exchange --book v2.sexp --out v2-out.sexp --date 2026-10-20 --id e --from bank-jpy jpy 100 --to cash-eur eur 60 >out 2>err
  [2]
  $ test ! -e v2-out.sexp && test ! -s out && grep -q 'version 3' err
