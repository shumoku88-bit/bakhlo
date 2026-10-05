The pure outer reader is usable without CLI/Presentation CMIs. It returns the
existing structured engine image/outcomes, not terminal strings or a forged zero.

  $ text_client() { ocamlfind ocamlc -package base,zarith -I ../lib/.bakhlo_domain.objs/byte -I ../application/.bakhlo_application.objs/byte -I ../text/.bakhlo_text.objs/byte -c "$@"; }
  $ cat >text_client.ml <<'EOF'
  > module R = Bakhlo_text.Read
  > module Q = Bakhlo_application.Current_quantity_query
  > let inspect bytes coordinate =
  >   match R.of_string bytes with
  >   | Error (R.Input error) -> `Input error
  >   | Error (R.Source error) -> `Source error
  >   | Error (R.Support error) -> `Support error
  >   | Ok image ->
  >     match Q.query image coordinate with
  >     | Error (Q.Support_unknown { coordinate }) -> `Unknown coordinate
  >     | Ok (Q.Known_present p) -> `Present (Q.present_coordinate p, Q.present_evidence p, Q.present_cut p)
  >     | Ok (Q.Exact a) -> `Exact (Q.coordinate a, Q.quantity a, Q.premise a, Q.source image, Q.source_groups image)
  > EOF
  $ text_client text_client.ml

Decoded input has not passed source/support admission and cannot be queried as an image.

  $ cat >unadmitted.ml <<'EOF'
  > let wrong (draft : Bakhlo_text.Input.t) coordinate =
  >   Bakhlo_application.Current_quantity_query.query draft coordinate
  > EOF
  $ text_client unadmitted.ml 2>error
  [2]
  $ grep -q 'Bakhlo_text.Input.t' error && grep -q 'Current_quantity_query.t' error

The local lexical mechanism is not a new public parser framework.

  $ cat >private_lexer.ml <<'EOF'
  > let wrong = Bakhlo_text.Text_line.decode
  > EOF
  $ text_client private_lexer.ml 2>error
  [2]
  $ grep -q 'Bakhlo_text.Text_line' error && grep -q 'Unbound module' error

The Unix shell only acquires a synthetic file and renders typed read/query outcomes.
No current household authority, recording acknowledgement or spending permission.

  $ bakhlo inspect-current-text --help
  Usage: bakhlo inspect-current-text [--explain] FILE LOCUS MEASURE [LOCUS MEASURE ...]
  Experimental bakhlo-read 1 ordinary-actual-quantity; synthetic read only.
  Exact/presence/unknown are conditional on supplied profile evidence.
  All questions use one wholly admitted supplied image; order/duplicates retained.
  With --explain, show supplied premises, Effects and retained correction paths.
  Exit 3 if any unsupported, else 4 if any presence, else 0; stdout.
  Not canonical storage, household authority, spending permission or Saved.
  $ cp ../examples/ordinary-quantity.bakhlo evidence
  $ cp evidence before
  $ chmod 400 evidence
  $ bakhlo inspect-current-text evidence wallet jpy
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  $ bakhlo inspect-current-text evidence food jpy
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  "food" / "jpy": zero-origin; quantity=160
  $ bakhlo inspect-current-text evidence wallet usd
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  "wallet" / "usd": opening Event "usd opening"; quantity=7
  $ bakhlo inspect-current-text evidence quiet jpy
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  "quiet" / "jpy": zero-origin; quantity=0
  $ bakhlo inspect-current-text evidence pantry jpy
  "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
  [4]
  $ bakhlo inspect-current-text evidence stale jpy
  "stale" / "jpy": quantity unknown (no supported premise in supplied evidence).
  [3]
  $ bakhlo inspect-current-text evidence unsupported jpy
  "unsupported" / "jpy": quantity unknown (no supported premise in supplied evidence).
  [3]
  $ cmp evidence before
  $ bakhlo inspect-current-text missing wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Cannot read synthetic text' err && test ! -e missing
  $ bakhlo inspect-current-text not-read '' jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'coordinate identities must not be empty' err
  $ bakhlo inspect-current-text not-read >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected FILE LOCUS MEASURE' err
  $ printf 'bakhlo-read 2 ordinary-actual-quantity\nend\n' >future
  $ bakhlo inspect-current-text future wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'unsupported version "2"' err

A richer fixture is not automatically promoted/translated into this profile.
Whole-document unsupported or semantic errors refuse even an unrelated supported lookup.

  $ bakhlo inspect-current-text ../examples/current-preview.fixture quiet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected bakhlo-read' err
  $ printf 'bakhlo-read 1 ordinary-actual-quantity\nmerchant "e" "p"\norigin "quiet" "jpy"\nend\n' >unsupported
  $ bakhlo inspect-current-text unsupported quiet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'outside profile' err
  $ printf 'bakhlo-read 1 ordinary-actual-quantity\nevent "e" none\nend-event\norigin "quiet" "jpy"\nend\n' >invalid
  $ cp invalid invalid-before
  $ bakhlo inspect-current-text invalid quiet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'missing current validity' err && cmp invalid invalid-before
  $ printf 'bakhlo-read 1 ordinary-actual-quantity\norigin "w" "jpy"\ngroup\nassert "w" "jpy" 0\nend-group\norigin "quiet" "jpy"\nend\n' >overlap
  $ bakhlo inspect-current-text overlap quiet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'zero-origin overlaps exact assertion' err
  $ cmp evidence before

Multiple questions keep their order, Measure and duplicate occurrences; mixed unknown wins
without a subtotal, a second source read, or pretending presence has an exact amount.

  $ bakhlo inspect-current-text evidence wallet jpy wallet usd quiet jpy pantry jpy stale jpy wallet jpy
  One supplied read image; independent questions (no subtotal).
  Question 1:
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  Question 2:
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  "wallet" / "usd": opening Event "usd opening"; quantity=7
  Question 3:
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  "quiet" / "jpy": zero-origin; quantity=0
  Question 4:
  "pantry" / "jpy": known nonzero (presence premise); exact quantity unknown.
  Question 5:
  "stale" / "jpy": quantity unknown (no supported premise in supplied evidence).
  Question 6:
  Conditional text quantity (ordinary-actual-quantity v1; synthetic).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  [3]
  $ bakhlo inspect-current-text --explain evidence wallet jpy stale jpy pantry jpy >out 2>err
  [3]
  $ test ! -s err && grep -Fq 'Correction "purchase draft" -> "purchase corrected"' out
  $ grep -Fq 'Root "purchase draft"; terminal "purchase corrected"; reflected (excluded).' out
  $ grep -Fq 'Effect 1: key "physical"; quanta=-150' out
  $ grep -Fq 'Effect 1: anonymous; quanta=-10' out
  $ grep -Fq 'ANY unreflected matching Effect invalidates it, even net zero' out
  $ grep -Fq 'exact quantity unknown' out && test "$(grep -c '^Question ' out)" = 3
  $ cmp evidence before

ALL argument pairs qualify before acquisition, and ALL supplied evidence qualifies before
any question output. A good first coordinate never permits partial source salvage.

  $ bakhlo inspect-current-text --explain not-read wallet jpy pantry '' >out 2>err
  [2]
  $ test ! -s out && grep -q 'coordinate identities must not be empty' err
  $ bakhlo inspect-current-text not-read wallet jpy dangling >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected FILE LOCUS MEASURE' err
  $ bakhlo inspect-current-text --explain missing wallet jpy quiet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Cannot read synthetic text' err && test ! -e missing
  $ bakhlo inspect-current-text --explain invalid quiet jpy wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'missing current validity' err && cmp invalid invalid-before
  $ bakhlo inspect-current-text --explain unsupported quiet jpy wallet jpy >out 2>err
  [2]
  $ test ! -s out && grep -q 'outside profile' err
  $ bakhlo inspect-current-text --explain overlap quiet jpy wallet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'zero-origin overlaps exact assertion' err

The scoped native LOAM reader uses the same pair/exit mechanics, never the text profile.
Only this supplied synthetic image is consumed; no operational root discovery.

  $ cp ../examples/loam-quantity.loam-input loam-evidence
  $ cp loam-evidence loam-before
  $ chmod 400 loam-evidence
  $ bakhlo inspect-loam-quantity loam-evidence wallet jpy food jpy wallet jpy
  One supplied read image; independent questions (no subtotal).
  Question 1:
  Conditional LOAM-input quantity (Actual/four-support read profile; not household authority).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  Question 2:
  Conditional LOAM-input quantity (Actual/four-support read profile; not household authority).
  "food" / "jpy": zero-origin; quantity=10
  Question 3:
  Conditional LOAM-input quantity (Actual/four-support read profile; not household authority).
  exact assertion; "wallet" / "jpy": asserted=1000; delta=-10; quantity=990
  $ bakhlo inspect-loam-quantity --explain loam-evidence wallet jpy pantry jpy >out 2>err
  [4]
  $ test ! -s err && grep -Fq 'Root "e"; terminal "e"; unreflected (contributes to delta).' out
  $ grep -Fq 'asserted=1000; delta=-10; quantity=990' out
  $ grep -Fq 'known nonzero (presence premise); exact quantity unknown' out
  $ bakhlo inspect-loam-quantity --explain loam-evidence pantry jpy missing jpy >out 2>err
  [3]
  $ test ! -s err && grep -Fq 'quantity unknown (no supported premise' out
  $ bakhlo inspect-loam-quantity --explain not-read wallet jpy food '' >out 2>err
  [2]
  $ test ! -s out && grep -q 'coordinate identities must not be empty' err
  $ bakhlo inspect-loam-quantity loam-evidence wallet jpy food >out 2>err
  [2]
  $ test ! -s out && grep -q 'expected FILE LOCUS MEASURE' err
  $ bakhlo inspect-loam-quantity --explain missing wallet jpy food jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'Cannot read input file' err && test ! -e missing
  $ bakhlo inspect-loam-quantity --explain evidence wallet jpy quiet jpy >out 2>err
  [1]
  $ test ! -s out && grep -q 'HouseholdImage' err
  $ cmp loam-evidence loam-before && cmp evidence before
